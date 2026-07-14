import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/models/plugin.dart';
import 'package:free_note/models/settings.dart';
import 'package:free_note/services/github_sync_service.dart';

void main() {
  group('GitHub device-flow models', () {
    test('DeviceCodeResponse parses required fields', () {
      final dc = DeviceCodeResponse.fromJson({
        'device_code': 'dc_123',
        'user_code': 'ABCD-1234',
        'verification_uri': 'https://github.com/login/device',
        'expires_in': 900,
        'interval': 5,
      });
      expect(dc.deviceCode, 'dc_123');
      expect(dc.userCode, 'ABCD-1234');
      expect(dc.verificationUri, 'https://github.com/login/device');
      expect(dc.expiresIn, 900);
      expect(dc.interval, 5);
    });

    test('GitHubRepo parses name, fullName, private', () {
      final repo = GitHubRepo.fromJson({
        'name': 'free-note',
        'full_name': 'IdentityVplayer/free-note',
        'private': true,
        'description': 'notes',
      });
      expect(repo.name, 'free-note');
      expect(repo.fullName, 'IdentityVplayer/free-note');
      expect(repo.private, isTrue);
      expect(repo.description, 'notes');
    });

    test('GitHubUser parses login', () {
      final user = GitHubUser.fromJson({'login': 'octocat'});
      expect(user.login, 'octocat');
    });
  });

  group('AppSettings GitHub fields', () {
    test('round-trips clientId and username', () {
      final s = AppSettings(
        githubToken: 'tok',
        githubRepo: 'a/b',
        githubClientId: 'client_1',
        githubUsername: 'octocat',
        autoSync: true,
      );
      final json = s.toJson();
      final back = AppSettings.fromJson(json);
      expect(back.githubToken, 'tok');
      expect(back.githubRepo, 'a/b');
      expect(back.githubClientId, 'client_1');
      expect(back.githubUsername, 'octocat');
      expect(back.autoSync, isTrue);
    });

    test('missing new fields default to null/false', () {
      final back = AppSettings.fromJson({'githubToken': 'tok'});
      expect(back.githubClientId, isNull);
      expect(back.githubUsername, isNull);
      expect(back.autoSync, isFalse);
    });
  });

  group('PluginInfo.hasSettings', () {
    test('serializes and deserializes hasSettings', () {
      final info = PluginInfo(
        id: 'builtin.githubsync',
        name: 'GitHub Sync',
        description: 'desc',
        version: '1.0.0',
        author: 'Borderless Notes',
        type: PluginType.utility,
        hasSettings: true,
      );
      final back = PluginInfo.fromJson(info.toJson());
      expect(back.hasSettings, isTrue);
      expect(back.type, PluginType.utility);
    });
  });
}
