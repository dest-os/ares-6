import 'package:flutter/material.dart';
import '../services/ares_service.dart';

/// ARES durum karti. Kapat (X) ile pasife alinabilir.
class AresOverlay extends StatelessWidget {
  final AresService ares;

  const AresOverlay({super.key, required this.ares});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ares,
      builder: (context, _) {
        if (ares.durum == AresDurum.pasif) {
          return const SizedBox.shrink();
        }

        String baslik;
        IconData ikon;
        switch (ares.durum) {
          case AresDurum.dinliyor:
            baslik = 'Dinliyorum...';
            ikon = Icons.mic;
            break;
          case AresDurum.isliyorum:
            baslik = 'Isleniyor...';
            ikon = Icons.hourglass_top;
            break;
          case AresDurum.konusuyor:
            baslik = 'ARES';
            ikon = Icons.remove_red_eye;
            break;
          case AresDurum.pasif:
            baslik = '';
            ikon = Icons.remove_red_eye;
            break;
        }

        final govdeMetni = ares.durum == AresDurum.dinliyor
            ? (ares.canliMetin.isEmpty ? 'Sizi dinliyorum...' : ares.canliMetin)
            : ares.sonYanit;

        return Positioned(
          left: 28,
          right: 28,
          bottom: 48,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00BFFF), width: 1.6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFFF).withOpacity(0.4),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(ikon, color: const Color(0xFF00BFFF), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          baslik,
                          style: const TextStyle(
                            color: Color(0xFF00BFFF),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      // Kapat dugmesi
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: () => ares.kapat(),
                        icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                  if (ares.sonSoylenen.isNotEmpty &&
                      (ares.durum == AresDurum.isliyorum ||
                          ares.durum == AresDurum.konusuyor)) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Siz: "${ares.sonSoylenen}"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (govdeMetni.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      govdeMetni,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
