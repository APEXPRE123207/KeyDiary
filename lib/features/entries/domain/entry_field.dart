enum EntryFieldType {
  text,
  longText,
  number,
  currency,
  date,
  phone,
  email,
  url,
  secret,
  boolean,
  image,
  document,
  locationDescription;

  static EntryFieldType fromString(String type) {
    switch (type.toUpperCase()) {
      case 'LONG_TEXT':
        return EntryFieldType.longText;
      case 'NUMBER':
        return EntryFieldType.number;
      case 'CURRENCY':
        return EntryFieldType.currency;
      case 'DATE':
        return EntryFieldType.date;
      case 'PHONE':
        return EntryFieldType.phone;
      case 'EMAIL':
        return EntryFieldType.email;
      case 'URL':
        return EntryFieldType.url;
      case 'SECRET':
      case 'SECRET CODE':
        return EntryFieldType.secret;
      case 'BOOLEAN':
      case 'YES/NO':
        return EntryFieldType.boolean;
      case 'IMAGE':
        return EntryFieldType.image;
      case 'DOCUMENT':
      case 'FILE':
        return EntryFieldType.document;
      case 'LOCATION_DESCRIPTION':
        return EntryFieldType.locationDescription;
      default:
        return EntryFieldType.text;
    }
  }

  String toDbString() {
    switch (this) {
      case EntryFieldType.longText:
        return 'LONG_TEXT';
      case EntryFieldType.number:
        return 'NUMBER';
      case EntryFieldType.currency:
        return 'CURRENCY';
      case EntryFieldType.date:
        return 'DATE';
      case EntryFieldType.phone:
        return 'PHONE';
      case EntryFieldType.email:
        return 'EMAIL';
      case EntryFieldType.url:
        return 'URL';
      case EntryFieldType.secret:
        return 'SECRET';
      case EntryFieldType.boolean:
        return 'BOOLEAN';
      case EntryFieldType.image:
        return 'IMAGE';
      case EntryFieldType.document:
        return 'DOCUMENT';
      case EntryFieldType.locationDescription:
        return 'LOCATION_DESCRIPTION';
      case EntryFieldType.text:
        return 'TEXT';
    }
  }

  String get displayName {
    switch (this) {
      case EntryFieldType.longText:
        return 'Long Note';
      case EntryFieldType.number:
        return 'Number';
      case EntryFieldType.currency:
        return 'Currency';
      case EntryFieldType.date:
        return 'Date';
      case EntryFieldType.phone:
        return 'Phone';
      case EntryFieldType.email:
        return 'Email';
      case EntryFieldType.url:
        return 'Website URL';
      case EntryFieldType.secret:
        return 'Secret Code';
      case EntryFieldType.boolean:
        return 'Yes / No';
      case EntryFieldType.image:
        return 'Image';
      case EntryFieldType.document:
        return 'File / Doc';
      case EntryFieldType.locationDescription:
        return 'Location Spot';
      case EntryFieldType.text:
        return 'Text';
    }
  }
}

/// Represents a single customizable field within an entry
class EntryField {
  final String id;
  final String entryId;
  final String fieldName; // Decrypted representation in domain
  final EntryFieldType fieldType;
  final String fieldValue; // Decrypted representation in domain
  final int position;
  final bool isSensitive;

  const EntryField({
    required this.id,
    required this.entryId,
    required this.fieldName,
    required this.fieldType,
    required this.fieldValue,
    this.position = 0,
    this.isSensitive = false,
  });

  EntryField copyWith({
    String? fieldName,
    EntryFieldType? fieldType,
    String? fieldValue,
    int? position,
    bool? isSensitive,
  }) {
    return EntryField(
      id: id,
      entryId: entryId,
      fieldName: fieldName ?? this.fieldName,
      fieldType: fieldType ?? this.fieldType,
      fieldValue: fieldValue ?? this.fieldValue,
      position: position ?? this.position,
      isSensitive: isSensitive ?? this.isSensitive,
    );
  }
}
