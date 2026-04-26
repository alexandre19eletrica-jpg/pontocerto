class InvoiceCustomer {
  const InvoiceCustomer({
    required this.id,
    required this.companyId,
    required this.legalName,
    required this.tradeName,
    required this.document,
    required this.email,
    required this.phone,
    required this.municipalRegistration,
    required this.stateRegistration,
    required this.zipCode,
    required this.street,
    required this.number,
    required this.complement,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.country,
    required this.notes,
    required this.createdAtIso,
    required this.updatedAtIso,
  });

  final String id;
  final String companyId;
  final String legalName;
  final String tradeName;
  final String document;
  final String email;
  final String phone;
  final String municipalRegistration;
  final String stateRegistration;
  final String zipCode;
  final String street;
  final String number;
  final String complement;
  final String neighborhood;
  final String city;
  final String state;
  final String country;
  final String notes;
  final String createdAtIso;
  final String updatedAtIso;

  factory InvoiceCustomer.fromMap(String id, Map<String, dynamic> map) {
    return InvoiceCustomer(
      id: id,
      companyId: map['companyId']?.toString() ?? '',
      legalName: map['legalName']?.toString() ?? '',
      tradeName: map['tradeName']?.toString() ?? '',
      document: map['document']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      municipalRegistration:
          map['municipalRegistration']?.toString() ?? '',
      stateRegistration: map['stateRegistration']?.toString() ?? '',
      zipCode: map['zipCode']?.toString() ?? '',
      street: map['street']?.toString() ?? '',
      number: map['number']?.toString() ?? '',
      complement: map['complement']?.toString() ?? '',
      neighborhood: map['neighborhood']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      country: map['country']?.toString() ?? 'BRASIL',
      notes: map['notes']?.toString() ?? '',
      createdAtIso: map['createdAtIso']?.toString() ?? '',
      updatedAtIso: map['updatedAtIso']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'legalName': legalName,
      'tradeName': tradeName,
      'document': document,
      'email': email,
      'phone': phone,
      'municipalRegistration': municipalRegistration,
      'stateRegistration': stateRegistration,
      'zipCode': zipCode,
      'street': street,
      'number': number,
      'complement': complement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'country': country,
      'notes': notes,
      'createdAtIso': createdAtIso,
      'updatedAtIso': updatedAtIso,
    };
  }
}
