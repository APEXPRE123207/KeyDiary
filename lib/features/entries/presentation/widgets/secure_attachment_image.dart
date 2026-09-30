import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/attachment.dart';

/// Securely loads an attachment image from local sandbox or private Supabase storage
class SecureAttachmentImage extends StatefulWidget {
  final Attachment attachment;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool isThumbnail;

  const SecureAttachmentImage({
    super.key,
    required this.attachment,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.isThumbnail = false,
  });

  @override
  State<SecureAttachmentImage> createState() => _SecureAttachmentImageState();
}

class _SecureAttachmentImageState extends State<SecureAttachmentImage> {
  Uint8List? _loadedBytes;
  File? _localFile;
  String? _signedUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant SecureAttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != widget.attachment.id ||
        oldWidget.attachment.localFilePath != widget.attachment.localFilePath ||
        oldWidget.attachment.storagePath != widget.attachment.storagePath) {
      _loadImage();
    }
  }

  Future<Uint8List?> _downloadUrlBytes(String url) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        return bytes;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final att = widget.attachment;

    // 1. Direct local file path check
    if (att.localFilePath != null && !kIsWeb) {
      final f = File(att.localFilePath!);
      if (await f.exists()) {
        if (mounted) {
          setState(() {
            _localFile = f;
            _isLoading = false;
          });
        }
        return;
      }
    }

    // 2. Direct check of standard local attachment directories
    if (!kIsWeb) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final tempDir = await getTemporaryDirectory();
        final cleanFileName = att.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final directCandidates = [
          File('${appDir.path}/attachments/${att.fileName}'),
          File('${appDir.path}/attachments/$cleanFileName'),
          if (att.id.isNotEmpty) File('${appDir.path}/attachments/${att.id}_${att.fileName}'),
          File('${appDir.path}/${att.fileName}'),
          File('${tempDir.path}/${att.fileName}'),
          File('${tempDir.path}/$cleanFileName'),
        ];

        for (final f in directCandidates) {
          if (await f.exists()) {
            if (mounted) {
              setState(() {
                _localFile = f;
                _isLoading = false;
              });
            }
            return;
          }
        }
      } catch (_) {}
    }

    // 3. Search attachments and temporary directories with comprehensive fuzzy matching
    if (!kIsWeb) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final tempDir = await getTemporaryDirectory();
        final dirsToCheck = [
          Directory('${appDir.path}/attachments'),
          Directory(tempDir.path),
        ];

        final cleanSearch = att.fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

        for (final dir in dirsToCheck) {
          if (await dir.exists()) {
            final files = dir.listSync().whereType<File>().toList();
            for (final entity in files) {
              final basename = entity.path.split(Platform.pathSeparator).last.toLowerCase();
              final cleanBase = basename.replaceAll(RegExp(r'[^a-z0-9]'), '');
              final stripTimestamp = basename.replaceFirst(RegExp(r'^\d+_'), '');

              if (basename == att.fileName.toLowerCase() ||
                  basename.endsWith(att.fileName.toLowerCase()) ||
                  stripTimestamp == att.fileName.toLowerCase() ||
                  (cleanSearch.isNotEmpty && (cleanBase.endsWith(cleanSearch) || cleanBase.contains(cleanSearch) || cleanSearch.contains(cleanBase))) ||
                  (att.id.isNotEmpty && basename.contains(att.id.toLowerCase()))) {
                if (mounted) {
                  setState(() {
                    _localFile = entity;
                    _isLoading = false;
                  });
                }
                return;
              }
            }
          }
        }
      } catch (_) {}
    }

    // 4. Check local entries store to find sibling or cached local file path
    if (!kIsWeb) {
      try {
        final localEntriesRaw = await SecureStorageService.getLocalEntries();
        for (final entryMap in localEntriesRaw) {
          final atts = (entryMap['attachments'] as List? ?? []);
          for (final a in atts) {
            final fPath = a['local_file_path'] as String? ?? a['localFilePath'] as String?;
            final fName = a['file_name'] as String? ?? a['fileName'] as String? ?? '';
            final aId = a['id'] as String? ?? '';
            if (fPath != null && (fName.toLowerCase() == att.fileName.toLowerCase() || (att.id.isNotEmpty && aId == att.id))) {
              final f = File(fPath);
              if (await f.exists()) {
                if (mounted) {
                  setState(() {
                    _localFile = f;
                    _isLoading = false;
                  });
                }
                return;
              }
            }
          }
        }
      } catch (_) {}
    }

    // 5. Supabase Private Storage (Authenticated Download) with multi-bucket support
    if (SupabaseService.isInitialized) {
      final buckets = const ['vault_attachments', 'attachments'];
      final rawPath = att.storagePath.trim();
      final cleanFileName = att.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final candidatePaths = <String>{
        if (rawPath.isNotEmpty) rawPath,
        if (rawPath.isNotEmpty) Uri.decodeComponent(rawPath),
        if (rawPath.isNotEmpty && !rawPath.startsWith('vaults/')) 'vaults/$rawPath',
        if (rawPath.isNotEmpty && rawPath.startsWith('vaults/')) rawPath.replaceFirst('vaults/', ''),
        if (rawPath.isNotEmpty && rawPath.contains('/')) rawPath.split('/').last,
        if (att.entryId.isNotEmpty && att.fileName.isNotEmpty) 'vaults/entries/${att.entryId}/${att.fileName}',
        if (att.entryId.isNotEmpty) 'vaults/entries/${att.entryId}/$cleanFileName',
        att.fileName,
        cleanFileName,
        Uri.decodeComponent(att.fileName),
      }.where((p) => p.isNotEmpty).toList();

      for (final bucket in buckets) {
        for (final path in candidatePaths) {
          try {
            final bytes = await Supabase.instance.client.storage
                .from(bucket)
                .download(path);

            if (bytes.isNotEmpty) {
              if (!kIsWeb) {
                try {
                  final appDir = await getApplicationDocumentsDirectory();
                  final attachmentsDir = Directory('${appDir.path}/attachments');
                  if (!await attachmentsDir.exists()) {
                    await attachmentsDir.create(recursive: true);
                  }
                  final permFile = File('${attachmentsDir.path}/${att.fileName}');
                  await permFile.writeAsBytes(bytes);
                  if (att.id.isNotEmpty) {
                    final idFile = File('${attachmentsDir.path}/${att.id}_${att.fileName}');
                    await idFile.writeAsBytes(bytes);
                  }

                  if (mounted) {
                    setState(() {
                      _localFile = permFile;
                      _loadedBytes = bytes;
                      _isLoading = false;
                    });
                    return;
                  }
                } catch (_) {}
              }

              if (mounted) {
                setState(() {
                  _loadedBytes = bytes;
                  _isLoading = false;
                });
              }
              return;
            }
          } catch (_) {}
        }
      }

      // Fallback: try signed URL with direct byte fetch
      for (final bucket in buckets) {
        for (final path in candidatePaths) {
          try {
            final url = await Supabase.instance.client.storage
                .from(bucket)
                .createSignedUrl(path, 3600);

            if (url.isNotEmpty) {
              final bytes = await _downloadUrlBytes(url);
              if (bytes != null && bytes.isNotEmpty) {
                if (!kIsWeb) {
                  try {
                    final appDir = await getApplicationDocumentsDirectory();
                    final attachmentsDir = Directory('${appDir.path}/attachments');
                    if (!await attachmentsDir.exists()) {
                      await attachmentsDir.create(recursive: true);
                    }
                    final permFile = File('${attachmentsDir.path}/${att.fileName}');
                    await permFile.writeAsBytes(bytes);

                    if (mounted) {
                      setState(() {
                        _localFile = permFile;
                        _loadedBytes = bytes;
                        _isLoading = false;
                      });
                      return;
                    }
                  } catch (_) {}
                }

                if (mounted) {
                  setState(() {
                    _loadedBytes = bytes;
                    _isLoading = false;
                  });
                }
                return;
              }

              if (mounted) {
                setState(() {
                  _signedUrl = url;
                  _isLoading = false;
                });
                return;
              }
            }
          } catch (_) {}
        }
      }
    }

    // If none succeeded
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: SizedBox(
            width: widget.isThumbnail ? 18 : 28,
            height: widget.isThumbnail ? 18 : 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (_localFile != null) {
      return Image.file(
        _localFile!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(isDark),
      );
    }

    if (_loadedBytes != null) {
      return Image.memory(
        _loadedBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(isDark),
      );
    }

    if (_signedUrl != null) {
      return Image.network(
        _signedUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildFallback(isDark),
      );
    }

    return _buildFallback(isDark);
  }

  Widget _buildFallback(bool isDark) {
    if (widget.isThumbnail) {
      return Icon(
        widget.attachment.isImage ? Icons.image : Icons.picture_as_pdf,
        color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
        size: 24,
      );
    }

    return Container(
      width: widget.width,
      height: widget.height ?? 220,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _hasError ? Icons.broken_image_outlined : Icons.lock_outline,
              size: 44,
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
            ),
            const SizedBox(height: 10),
            Text(
              widget.attachment.fileName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.attachment.formattedSize} • Encrypted photo',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
