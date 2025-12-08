import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<String?> uploadAvatar(File file, String userId) async {
  final fileExt = file.path.split('.').last;
  final fileName = "$userId.$fileExt";

  final res = await supabase.storage
      .from('avatars')
      .upload(
    fileName,
    file,
    fileOptions: const FileOptions(upsert: true),
  );

  if (res != null) {
    final url = supabase.storage.from('avatars').getPublicUrl(fileName);

    // SIMPAN URL KE DATABASE
    await supabase
        .from('profiles')
        .update({
      'avatar_url': url,
    })
        .eq('id', userId);

    return url;
  }

  return null;
}