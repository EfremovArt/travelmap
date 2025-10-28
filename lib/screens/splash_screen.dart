import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Set transparent status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D0918), // Dark background #0D0918
      body: Stack(
        children: [
          // Main content
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate responsive sizes based on screen dimensions
                final screenWidth = constraints.maxWidth;
                
                // Base design is for 428px width
                final baseWidth = 428.0;
                final scaleFactor = screenWidth / baseWidth;
                
                // Responsive font size
                final baseFontSize = 50.2514;
                final fontSize = baseFontSize * scaleFactor;
                
                // Adjust font size for different screen sizes using media queries
                double responsiveFontSize = fontSize;
                if (screenWidth < 360) {
                  // Small phones
                  responsiveFontSize = fontSize * 0.8;
                } else if (screenWidth > 600) {
                  // Tablets
                  responsiveFontSize = fontSize * 1.2;
                } else if (screenWidth > 900) {
                  // Large tablets/Desktop
                  responsiveFontSize = fontSize * 1.5;
                }
                
                return Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "Travel" text - using Rubik One font (ensures uppercase 'T')
                      Text(
                        'Travel',
                        style: TextStyle(
                          fontFamily: 'Rubik One',
                          fontWeight: FontWeight.w400,
                          fontSize: responsiveFontSize,
                          height: 57 / baseFontSize,
                          letterSpacing: -0.554124 * scaleFactor,
                          color: Colors.white,
                        ),
                      ),
                      // "Map" word with forced uppercase 'M' using a font that has a clear uppercase glyph
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'M',
                              style: TextStyle(
                                fontFamily: 'Rubik One', // strong uppercase 'M'
                                fontWeight: FontWeight.w400,
                                fontSize: responsiveFontSize,
                                height: 57 / baseFontSize,
                                letterSpacing: -0.554124 * scaleFactor,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: 'ap',
                              style: TextStyle(
                                fontFamily: 'Rubik Microbe',
                                fontWeight: FontWeight.w400,
                                fontSize: responsiveFontSize,
                                height: 57 / baseFontSize,
                                letterSpacing: -0.554124 * scaleFactor,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

