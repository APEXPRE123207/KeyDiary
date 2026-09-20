import 'package:flutter_test/flutter_test.dart';
import 'package:keydiary/features/entries/domain/attachment.dart';
import 'package:keydiary/features/entries/domain/entry.dart';
import 'package:keydiary/features/entries/domain/entry_field.dart';

void main() {
  group('Entry & EntryField Model Tests', () {
    test('Entry accurately resolves custom field values by name', () {
      final entry = Entry(
        id: 'entry-1',
        categoryId: 'cat-1',
        vaultId: 'vault-1',
        title: 'SBI Fixed Deposit',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fields: const [
          EntryField(
            id: 'f1',
            entryId: 'entry-1',
            fieldName: 'Deposit Amount',
            fieldType: EntryFieldType.currency,
            fieldValue: '5,00,000',
          ),
          EntryField(
            id: 'f2',
            entryId: 'entry-1',
            fieldName: 'Locker Key Number',
            fieldType: EntryFieldType.secret,
            fieldValue: 'LK-994',
            isSensitive: true,
          ),
        ],
      );

      expect(entry.getFieldValue('Deposit Amount'), equals('5,00,000'));
      expect(entry.getFieldValue('deposit amount'), equals('5,00,000')); // case-insensitive
      expect(entry.getFieldValue('Locker Key Number'), equals('LK-994'));
      expect(entry.getFieldValue('NonExistent'), isNull);
    });

    test('EntryFieldType string conversions preserve database enum mappings', () {
      expect(EntryFieldType.fromString('CURRENCY'), equals(EntryFieldType.currency));
      expect(EntryFieldType.fromString('SECRET CODE'), equals(EntryFieldType.secret));
      expect(EntryFieldType.fromString('YES/NO'), equals(EntryFieldType.boolean));
      expect(EntryFieldType.secret.toDbString(), equals('SECRET'));
      expect(EntryFieldType.currency.toDbString(), equals('CURRENCY'));
    });

    test('Attachment correctly detects image types and formats file sizes', () {
      final imgAtt = Attachment(
        id: 'att-1',
        entryId: 'e-1',
        storagePath: 'vaults/v1/entries/receipt.jpg',
        fileName: 'receipt.jpg',
        mimeType: 'image/jpeg',
        size: 1572864, // 1.5 MB
        createdAt: DateTime.now(),
      );

      final pdfAtt = Attachment(
        id: 'att-2',
        entryId: 'e-1',
        storagePath: 'vaults/v1/entries/deed.pdf',
        fileName: 'deed.pdf',
        mimeType: 'application/pdf',
        size: 512000, // 500 KB
        createdAt: DateTime.now(),
      );

      expect(imgAtt.isImage, isTrue);
      expect(imgAtt.isPdf, isFalse);
      expect(imgAtt.formattedSize, equals('1.5 MB'));

      expect(pdfAtt.isImage, isFalse);
      expect(pdfAtt.isPdf, isTrue);
      expect(pdfAtt.formattedSize, equals('500.0 KB'));
    });
  });
}
