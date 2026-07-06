import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Clé unique du Scaffold principal de l'application, qui contient le menu
/// latéral (Drawer). Chaque page utilise cette clé pour pouvoir ouvrir le
/// menu depuis son propre bouton ☰, même si elle a son propre Scaffold interne.
final scaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>((ref) {
  return GlobalKey<ScaffoldState>();
});
