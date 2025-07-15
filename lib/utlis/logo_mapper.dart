String logoForMerchant(String name) {
  final key = name.toLowerCase();
  if (key.contains('netflix'))      return 'assets/images/netflix.png';
  if (key.contains('spotify'))      return 'assets/images/spotify.png';
  if (key.contains('shahid'))       return 'assets/images/shahid.png';
  return 'assets/images/default.png';
}

String logoForIssuer(String issuer) {
  final key = issuer.toLowerCase();
  if (key.contains('arab bank'))    return 'assets/images/arab_bank.png';
  if (key.contains('zain cash'))    return 'assets/images/zain.jpg';
  // …
  return 'assets/images/default.png';
}
