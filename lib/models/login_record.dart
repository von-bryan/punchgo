class LoginRecord {
  final int? loginId;
  final int empId;
  final String time;
  final String date;
  final String state; // 'IN' or 'OUT'
  final int? syncId;
  final String? loginStatus;
  final String? swipe;
  final String? originalTime;
  final String? changedBy;
  final String? changeOn;
  final String? remarks;

  LoginRecord({
    this.loginId,
    required this.empId,
    required this.time,
    required this.date,
    required this.state,
    this.syncId,
    this.loginStatus,
    this.swipe,
    this.originalTime,
    this.changedBy,
    this.changeOn,
    this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'login_id': loginId,
      'emp_id': empId,
      'time': time,
      'date': date,
      'state': state,
      'sync_id': syncId,
      'login_status': loginStatus,
      'swipe': swipe,
      'original_time': originalTime,
      'changed_by': changedBy,
      'change_on': changeOn,
      'remarks': remarks,
    };
  }

  factory LoginRecord.fromMap(Map<String, dynamic> map) {
    return LoginRecord(
      loginId: map['login_id'] is String 
          ? int.tryParse(map['login_id']) 
          : map['login_id'],
      empId: map['emp_id'] is String 
          ? int.parse(map['emp_id']) 
          : map['emp_id'],
      time: map['time']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      syncId: map['sync_id'] is String 
          ? int.tryParse(map['sync_id']) 
          : map['sync_id'],
      loginStatus: map['login_status']?.toString(),
      swipe: map['swipe']?.toString(),
      originalTime: map['original_time']?.toString(),
      changedBy: map['changed_by']?.toString(),
      changeOn: map['change_on']?.toString(),
      remarks: map['remarks']?.toString(),
    );
  }
}
