// lib/data/location_data.dart

class AppData {
  static const List<String> onlineCategories = [
    'Financial Fraud (MFS)',
    'E-Commerce Scam',
    'Cyberbullying / Harassment',
    'Blackmail / Sextortion',
    'Identity Theft / Impersonation',
    'Hacking',
    'Phishing Links',
    'Rumor / Hate Speech',
    'Other',
  ];

  static const List<String> offlineCategories = [
    'Theft / Mugging',
    'Bribery / Corruption',
    'Physical Assault / Fighting',
    'Sexual Harassment / Stalking',
    'Drug Dealing / Usage',
    'Robbery / Dacoity',
    'Vandalism / Property Damage',
    'Domestic Violence',
    'Kidnapping / Missing Person',
    'Other',
  ];

  // Map of City -> List of Areas
  static const Map<String, List<String>> bangladeshLocations = {
    'Dhaka': [
      'Mirpur', 'Uttara', 'Dhanmondi', 'Gulshan', 'Banani', 'Mohakhali',
      'Motijheel', 'Old Dhaka', 'Badda', 'Rampura', 'Farmgate', 'Tejgaon'
    ],
    'Chittagong': [
      'Agrabad', 'GEC Circle', 'Kotwali', 'Halishahar', 'Pahartali',
      'Khulshi', 'Patenga', 'Nasirabad'
    ],
    'Narayanganj': [
      'Chashara', 'Siddhirganj', 'Fatullah', 'Pagla', 'Sonargaon',
      'Rupganj', 'Bandar'
    ],
    'Sylhet': [
      'Zindabazar', 'Amberkhana', 'Subidbazar', 'Shibganj', 'Tilagor'
    ],
    'Rajshahi': [
      'Shaheb Bazar', 'Motihar', 'Boalia', 'Kazla'
    ],
    'Khulna': [
      'Sonadanga', 'Khalishpur', 'Daulatpur', 'Boyra'
    ],
    'Barisal': [
      'Sadar Road', 'Rupatali', 'Nathullabad'
    ],
    'Rangpur': [
      'Jahaj Company Mor', 'Dhap', 'Carmichael College Area'
    ],
    'Comilla': [
      'Kandirpar', 'Race Course', 'Tomsom Bridge'
    ],
    'Gazipur': [
      'Tongi', 'Joydebpur', 'Board Bazar', 'Konabari'
    ]
  };
}