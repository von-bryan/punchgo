class Employee {
  final int? empCode;
  final int empId;
  final String? isAgency;
  final String? alias;
  final String surname;
  final String firstName;
  final String? middleName;
  final String? qualifier;
  final String? salutation;
  final String? sex;
  final String? birthDate;
  final String? birthPlace;
  final String? maritalStatus;
  final String? religion;
  final String? citizenship;
  final String? acrNo;
  final String? bloodType;
  final String? referenceId;
  final int? noOfDependents;
  final String? headOfFamily;
  final String status;
  final String? hasOtherEmployer;
  final String? email;
  final String? emailId;
  final String? caseSensitive;
  final String? faceDescriptors;
  final String? gmailId;
  final String? photoPath; // Path to uploaded photo on server

  Employee({
    this.empCode,
    required this.empId,
    this.isAgency,
    this.alias,
    required this.surname,
    required this.firstName,
    this.middleName,
    this.qualifier,
    this.salutation,
    this.sex,
    this.birthDate,
    this.birthPlace,
    this.maritalStatus,
    this.religion,
    this.citizenship,
    this.acrNo,
    this.bloodType,
    this.referenceId,
    this.noOfDependents,
    this.headOfFamily,
    this.status = 'Active',
    this.hasOtherEmployer,
    this.email,
    this.emailId,
    this.caseSensitive,
    this.faceDescriptors,
    this.gmailId,
    this.photoPath,
  });

  String get fullName => '$firstName ${middleName ?? ''} $surname'.trim();

  Map<String, dynamic> toMap() {
    return {
      'emp_code': empCode,
      'emp_id': empId,
      'isAgency': isAgency,
      'alias': alias,
      'surname': surname,
      'first_name': firstName,
      'middle_name': middleName,
      'qualifier': qualifier,
      'salutation': salutation,
      'sex': sex,
      'birth_date': birthDate,
      'birth_place': birthPlace,
      'marital_status': maritalStatus,
      'religion': religion,
      'citizenship': citizenship,
      'acr_no': acrNo,
      'blood_type': bloodType,
      'reference_id': referenceId,
      'no_of_dependents': noOfDependents,
      'head_of_family': headOfFamily,
      'status': status,
      'has_other_employer': hasOtherEmployer,
      'email': email,
      'email_id': emailId,
      'case_sensitive': caseSensitive,
      'face_descriptors': faceDescriptors,
      'gmail_id': gmailId,
      'photo_path': photoPath,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      empCode: map['emp_code'] is String 
          ? int.tryParse(map['emp_code']) 
          : map['emp_code'],
      empId: map['emp_id'] is String 
          ? int.parse(map['emp_id']) 
          : map['emp_id'],
      isAgency: map['isAgency']?.toString(),
      alias: map['alias']?.toString(),
      surname: map['surname']?.toString() ?? '',
      firstName: map['first_name']?.toString() ?? '',
      middleName: map['middle_name']?.toString(),
      qualifier: map['qualifier']?.toString(),
      salutation: map['salutation']?.toString(),
      sex: map['sex']?.toString(),
      birthDate: map['birth_date']?.toString(),
      birthPlace: map['birth_place']?.toString(),
      maritalStatus: map['marital_status']?.toString(),
      religion: map['religion']?.toString(),
      citizenship: map['citizenship']?.toString(),
      acrNo: map['acr_no']?.toString(),
      bloodType: map['blood_type']?.toString(),
      referenceId: map['reference_id']?.toString(),
      noOfDependents: map['no_of_dependents'] is String 
          ? int.tryParse(map['no_of_dependents']) 
          : map['no_of_dependents'],
      headOfFamily: map['head_of_family']?.toString(),
      status: map['status']?.toString() ?? 'Active',
      hasOtherEmployer: map['has_other_employer']?.toString(),
      email: map['email']?.toString(),
      emailId: map['email_id']?.toString(),
      caseSensitive: map['case_sensitive']?.toString(),
      faceDescriptors: map['face_descriptors']?.toString(),
      gmailId: map['gmail_id']?.toString(),
      photoPath: map['photo_path']?.toString(),
    );
  }
}
