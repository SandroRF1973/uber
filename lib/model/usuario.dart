class Usuario {
  String? _idUsuario;
  String? _nome;
  String? _email;
  String? _senha;
  String? _tipoUsuario;

  double? _latitude;
  double? _longitude;

  Usuario();

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      "nome": nome,
      "email": email,
      "tipoUsuario": tipoUsuario
    };

    return map;
  }

  String verificaTipoUsuario(bool tipoUsuario) {
    return tipoUsuario ? "motorista" : "passageiro";
  }

  String get idUsuario => _idUsuario!;

  set idUsuario(String value) {
    _idUsuario = value;
  }

  String get nome => _nome!;

  set nome(String value) {
    _nome = value;
  }

  String get email => _email!;

  set email(String value) {
    _email = value;
  }

  String get senha => _senha!;

  set senha(String value) {
    _senha = value;
  }

  String get tipoUsuario => _tipoUsuario!;

  set tipoUsuario(String value) {
    _tipoUsuario = value;
  }

  double get latitude => _latitude!;

  set latitude(double value) {
    _latitude = value;
  }

  double get longitude => _longitude!;

  set longitude(double value) {
    _longitude = value;
  }
}
