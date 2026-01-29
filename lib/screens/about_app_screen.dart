import 'package:flutter/material.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Justice Link BD'),
        backgroundColor: const Color(0xFF6C63FF),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Icon and Name
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.security,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Justice Link BD',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Your Safety, Our Priority',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // App Overview in Bangla
              Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info, color: Colors.blueAccent),
                          SizedBox(width: 10),
                          Text(
                            'অ্যাপ সম্পর্কে',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Justice Link BD হল বাংলাদেশের প্রথম সম্পূর্ণ ডিজিটাল নিরাপত্তা ও জরুরী সহায়তা অ্যাপ্লিকেশন। '
                            'এই অ্যাপটি সাধারণ নাগরিকদের জন্য ডিজাইন করা হয়েছে যারা দ্রুত ও কার্যকরীভাবে অপরাধ রিপোর্ট করতে চান '
                            'এবং জরুরী অবস্থায় সাহায্য চাইতে চান।',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // How It Works in Bangla
              Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.phone_android, color: Colors.greenAccent),
                          SizedBox(width: 10),
                          Text(
                            'কিভাবে কাজ করে',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      _buildFeatureItem(
                        '📱 রিপোর্ট জমা দিন',
                        'অনলাইন বা অফলাইন যেকোনো অপরাধের বিস্তারিত বিবরণ, ছবি, অডিও এবং লোকেশনসহ রিপোর্ট করুন।',
                      ),

                      _buildFeatureItem(
                        '🚨 জরুরী SOS',
                        'বিপদে পড়লে সস বাটন টাচ করে রাখুন। আপনার লোকেশন স্বয়ংক্রিয়ভাবে পুলিশ ও নিকটবর্তী ব্যবহারকারীদের কাছে শেয়ার হবে।',
                      ),

                      _buildFeatureItem(
                        '📍 রিয়েল-টাইম লোকেশন',
                        'জরুরী অবস্থায় আপনার বর্তমান অবস্থান স্বয়ংক্রিয়ভাবে শেয়ার হয় এবং নিকটবর্তী ইউজারদের নোটিফিকেশন যায়।',
                      ),

                      _buildFeatureItem(
                        '🤖 AI ভেরিফিকেশন',
                        'আর্টিফিশিয়াল ইন্টেলিজেন্সের মাধ্যমে রিপোর্টের সত্যতা যাচাই করা হয়, বিশেষ করে হত্যা/খুনের ক্ষেত্রে ছবি ভেরিফিকেশন বাধ্যতামূলক।',
                      ),

                      _buildFeatureItem(
                        '👥 কমিউনিটি সাপোর্ট',
                        'আপনার এলাকার অন্যান্য ব্যবহারকারীরা আপনার জরুরী অবস্থা দেখতে পায় এবং সাহায্য করতে আসতে পারে।',
                      ),

                      _buildFeatureItem(
                        '📊 টাইমলাইন',
                        'আপনার এলাকার সব রিপোর্ট দেখুন এবং কমিউনিটির সাথে ভোট দিন রিপোর্টের সত্যতা যাচাই করতে।',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // How to Use in Bangla
              Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.help_outline, color: Colors.orangeAccent),
                          SizedBox(width: 10),
                          Text(
                            'ব্যবহার পদ্ধতি',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      _buildStepItem('১', 'অ্যাপ ডাউনলোড করে রেজিস্ট্রেশন করুন'),
                      _buildStepItem('২', 'প্রোফাইল পূরণ করুন এবং ভেরিফাই করুন'),
                      _buildStepItem('৩', 'রিপোর্ট করতে "Report" ট্যাবে যান'),
                      _buildStepItem('৪', 'অপরাধের ধরন (অনলাইন/অফলাইন) নির্বাচন করুন'),
                      _buildStepItem('৫', 'বিস্তারিত বিবরণ, ছবি এবং লোকেশন যোগ করুন'),
                      _buildStepItem('৬', 'জরুরী অবস্থায় SOS বাটন প্রেস করুন'),
                      _buildStepItem('৭', 'টাইমলাইনে অন্যান্য রিপোর্ট দেখুন এবং ভোট দিন'),
                      _buildStepItem('৮', 'জরুরী সাপোর্ট ট্যাবে অন্যের সাহায্য করুন'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Safety Features
              Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.security, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text(
                            'নিরাপত্তা বৈশিষ্ট্য',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      _buildSafetyItem('🔒 এন্ড-টু-এন্ড এনক্রিপশন', 'সমস্ত ডেটা সুরক্ষিত থাকে'),
                      _buildSafetyItem('👁️‍🗨️ এনোনিমিটি অপশন', 'প্রাইভেসি রক্ষার জন্য'),
                      _buildSafetyItem('🤖 AI ফেক ডিটেকশন', 'ভুয়া রিপোর্ট চিহ্নিত করে'),
                      _buildSafetyItem('📍 লোকেশন মাস্কিং', 'সুনির্দিষ্ট লোকেশন গোপন রাখে'),
                      _buildSafetyItem('📞 সরাসরি পুলিশ কানেকশন', 'জরুরী কন্টাক্ট'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Contact Information
              Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.contact_support, color: Colors.purpleAccent),
                          SizedBox(width: 10),
                          Text(
                            'যোগাযোগ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      _buildContactItem(
                        'জরুরী হেল্পলাইন',
                        '৯৯৯',
                        Icons.emergency,
                        Colors.red,
                      ),

                      _buildContactItem(
                        'সাপোর্ট ইমেইল',
                        'support@justicelinkbd.com',
                        Icons.email,
                        Colors.blue,
                      ),

                      _buildContactItem(
                        'ওয়েবসাইট',
                        'www.justicelinkbd.com',
                        Icons.language,
                        Colors.green,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // App Version
              Center(
                child: Text(
                  'ভার্সন 1.0.1 • © 2026 Justice Link BD',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyItem(String feature, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(String title, String info, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}