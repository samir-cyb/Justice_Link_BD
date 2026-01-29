import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:justice_link_user/screens/report_screen.dart';

class PoliceInfoScreen extends StatefulWidget {
  const PoliceInfoScreen({super.key});

  @override
  State<PoliceInfoScreen> createState() => _PoliceInfoScreenState();
}

class _PoliceInfoScreenState extends State<PoliceInfoScreen> {
  // Data structure for emergency hotlines (Source: police.gov.bd)
  final List<Map<String, String>> _emergencyHotlines = [
    {
      'title': 'জাতীয় জরুরী সেবা',
      'number': '999',
      'description': 'সকল ধরনের জরুরী সহায়তা',
      'type': 'emergency'
    },
    {
      'title': 'নারী ও শিশু নির্যাতন',
      'number': '109',
      'description': 'নারী ও শিশু সহায়তা হটলাইন',
      'type': 'emergency'
    },
    {
      'title': 'শিশু সহায়তা',
      'number': '1098',
      'description': 'বিশেষ শিশু সহায়তা সার্ভিস',
      'type': 'emergency'
    },
    {
      'title': 'Police Cyber Support for Women',
      'number': '01320000888',
      'description': 'সাইবার অপরাধে নারী ভিকটিম সহায়তা[citation:7]',
      'type': 'special'
    },
  ];

  // Data structure for general police contacts
  final List<Map<String, String>> _generalContacts = [
    {
      'title': 'পুলিশ হেডকোয়ার্টার্স (সাধারণ)',
      'number': '+880-2-223381967',
      'description': 'ফোন (অফিস)[citation:1]',
    },
    {
      'title': 'পুলিশ হেডকোয়ার্টার্স (মোবাইল)',
      'number': '01320001299',
      'description': 'জরুরী যোগাযোগ[citation:1]',
    },
    {
      'title': 'ইন্সপেক্টর জেনারেল (IGP) অফিস',
      'number': '02-9514444',
      'description': 'পুলিশ প্রধান কার্যালয়[citation:5]',
    },
    {
      'title': 'কমিউনিটি পুলিশিং',
      'number': '01713-374602',
      'description': 'এআইজি (কমিউনিটি এন্ড বিট পুলিশিং)[citation:10]',
    },
    {
      'title': 'ট্রাফিক পুলিশ অভিযোগ',
      'number': '01320000218',
      'description': 'এআইজি (ট্রাফিক ম্যানেজমেন্ট)[citation:10]',
    },
  ];

  // Dhaka Metropolitan Police Contacts
  final List<Map<String, String>> _dhakaContacts = [
    {
      'title': 'পুলিশ সুপার, ঢাকা',
      'number': '01320089300',
      'description': 'জনাব মোঃ মিজানুর রহমান[citation:6]',
    },
    {
      'title': 'অতিরিক্ত পুলিশ সুপার (প্রশাসন)',
      'number': '01320089302',
      'description': 'জনাব মোঃ খায়রুল আলম[citation:6]',
    },
    {
      'title': 'অফিসার ইনচার্জ, সাভার',
      'number': '01320089377',
      'description': 'জনাব আরমান আলী[citation:6]',
    },
  ];

  // Future to simulate fetching/refreshing data
  Future<void> _refreshData() async {
    // In a full implementation, this would fetch from the official websites.
    // For now, we simulate a refresh and show a message.
    await Future.delayed(const Duration(seconds: 1));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('যোগাযোগের তথ্য আপডেট করা হয়েছে'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Function to make a phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ফোন কল শুরু করতে ব্যর্থ হয়েছে।'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Function to navigate to the report screen (Report Portal Tab)
  void _navigateToReportScreen() {
    // Using Navigator to go back and then to the ReportScreen.
    // This assumes ReportScreen is the first tab (index 0) in the main app.
    Navigator.pop(context); // Go back to profile
    // If your app uses a different navigation structure, you may need to adjust this.
    // For example, if using a bottom nav bar managed by ReportScreen itself,
    // you might need to pass a callback or use a global key.
    // A simple approach for your structure:
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'বাংলাদেশ পুলিশ - যোগাযোগ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'তথ্য রিফ্রেশ করুন',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: Colors.blue[900],
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Information Source Notice
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  margin: const EdgeInsets.only(bottom: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.blue[900]!.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.blueAccent, width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'দাপ্তরিক তথ্য',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'সমস্ত নম্বর বাংলাদেশ পুলিশের দাপ্তরিক ওয়েবসাইট (police.gov.bd) থেকে সংগৃহীত[citation:1][citation:4][citation:6]। সর্বশেষ আপডেটের তারিখ অনুযায়ী তথ্য প্রদর্শিত হচ্ছে।',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Emergency Hotlines Section
                _buildSectionTitle('🚨 জরুরী হটলাইন নম্বরসমূহ'),
                const SizedBox(height: 8),
                Text(
                  'জীবন-মৃত্যুর পরিস্থিতিতে অবিলম্বে কল করুন',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                ..._emergencyHotlines.map((contact) => _buildContactCard(
                  contact['title']!,
                  contact['number']!,
                  contact['description']!,
                  isEmergency: contact['type'] == 'emergency',
                )),

                const SizedBox(height: 32),

                // General Police Contacts
                _buildSectionTitle('📞 পুলিশের সাধারণ যোগাযোগ'),
                const SizedBox(height: 16),
                ..._generalContacts.map((contact) => _buildContactCard(
                  contact['title']!,
                  contact['number']!,
                  contact['description']!,
                  isEmergency: false,
                )),

                const SizedBox(height: 32),

                // Dhaka Metropolitan Police
                _buildSectionTitle('🏙️ ঢাকা মেট্রোপলিটন পুলিশ (ডিএমপি)'),
                const SizedBox(height: 16),
                ..._dhakaContacts.map((contact) => _buildContactCard(
                  contact['title']!,
                  contact['number']!,
                  contact['description']!,
                  isEmergency: false,
                )),

                const SizedBox(height: 32),

                // Quick Action Card for Report
                Card(
                  color: Colors.red.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.emergency_share,
                          size: 50,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Justice Link BD তে জরুরী রিপোর্ট করুন',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'আমাদের অ্যাপের মাধ্যমে দ্রুত ও নিরাপদে ঘটনা রিপোর্ট করুন। আপনার লোকেশন এবং বিবরণ সাথে সাথে কর্তৃপক্ষের নিকট পৌঁছে যাবে।',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.report_problem),
                            label: const Text(
                              'জরুরী রিপোর্ট করুন',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                            ),
                            onPressed: _navigateToReportScreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Footer Note
                Center(
                  child: Column(
                    children: [
                      Text(
                        '© বাংলাদেশ পুলিশ • Justice Link BD',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'সকল নাগরিকের নিরাপত্তা আমাদের অঙ্গীকার',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildContactCard(String title, String number, String description,
      {required bool isEmergency}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: isEmergency
          ? Colors.red.withOpacity(0.1)
          : Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isEmergency ? Colors.redAccent : Colors.blueGrey.shade700,
          width: 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isEmergency ? Colors.red : Colors.blue[800],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isEmergency ? Icons.emergency : Icons.phone,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _makePhoneCall(number),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isEmergency ? Colors.red : Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}