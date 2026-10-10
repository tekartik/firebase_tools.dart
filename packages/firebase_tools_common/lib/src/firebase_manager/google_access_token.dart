/// Provides a Google OAuth2 access token for the Google REST APIs (Firebase
/// management, hosting, cloud monitoring).
///
/// The io implementations (Firebase CLI login, gcloud) are in
/// `firebase_manager_io.dart`, a web app supplies its own token with
/// [GoogleAccessTokenProvider.function].
abstract class GoogleAccessTokenProvider {
  /// A valid access token, refreshed when needed.
  Future<String> getAccessToken();

  /// Project billed for the calls (`x-goog-user-project` header), null when
  /// not needed.
  String? get quotaProjectId;

  /// Account description for display (email or credentials source).
  Future<String> getAccountDescription();

  /// Provider calling [getAccessToken] for each token, which should cache
  /// it.
  factory GoogleAccessTokenProvider.function(
    Future<String> Function() getAccessToken, {
    String description,
    String? quotaProjectId,
  }) = _GoogleAccessTokenProviderFunction;
}

class _GoogleAccessTokenProviderFunction implements GoogleAccessTokenProvider {
  final Future<String> Function() _getAccessToken;
  final String description;
  @override
  final String? quotaProjectId;

  _GoogleAccessTokenProviderFunction(
    this._getAccessToken, {
    this.description = 'access token',
    this.quotaProjectId,
  });

  @override
  Future<String> getAccessToken() => _getAccessToken();

  @override
  Future<String> getAccountDescription() async => description;
}

/// An access token and its expiration time.
class GoogleAccessToken {
  /// The token.
  final String token;

  /// Expiration time.
  final DateTime expiresAt;

  /// An access token and its expiration time.
  GoogleAccessToken(this.token, this.expiresAt);

  /// True if still valid for at least a minute.
  bool get isValid =>
      DateTime.now().add(const Duration(minutes: 1)).isBefore(expiresAt);
}
