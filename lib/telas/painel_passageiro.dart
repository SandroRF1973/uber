import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:uber/model/destino.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uber/model/marcador.dart';
import 'package:uber/model/requisicao.dart';
import 'package:uber/model/usuario.dart';
import 'package:uber/util/status_requisicao.dart';
import 'package:uber/util/usuario_firebase.dart';

class PainelPassageiro extends StatefulWidget {
  const PainelPassageiro({super.key});

  @override
  State<PainelPassageiro> createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {
  final TextEditingController _controllerDestino = TextEditingController();

  List<String> itensMenu = ["Configurações", "Deslogar"];

  final Completer<GoogleMapController> _controller = Completer();
  final CameraPosition _posicaoCamera =
      const CameraPosition(target: LatLng(-23.563999, -46.653256));

  Set<Marker> _marcadores = {};

  String? _idRequisicao;
  late Position _localPassageiro;
  late Map<String, dynamic> _dadosRequisicao;

  late StreamSubscription<DocumentSnapshot> _streamSubscriptionRequisicoes;

  bool _exibirCaixaEnderecoDestino = true;
  String _textoBotao = "Chamar uber";
  Color _corBotao = const Color(0xff1ebbd8);
  late Function _funcaoBotao;

  _deslogarUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;

    await auth.signOut();

    // ignore: use_build_context_synchronously
    Navigator.pushReplacementNamed(context, "/");
  }

  _escolhaMenuItem(String escolha) {
    switch (escolha) {
      case "Deslogar":
        _deslogarUsuario();
        break;
      case "Configurações":
        break;
    }
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionarListenerLocalizacao() {
    var locationOptions = const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 10);

    Geolocator.getPositionStream(locationSettings: locationOptions)
        .listen((Position position) {
      if (_idRequisicao != null && _idRequisicao!.isNotEmpty) {
        //Atualiza local do passageiro
        UsuarioFirebase.atualizarDadosLocalizacao(
            _idRequisicao!, position.latitude, position.longitude);

        // ignore: unnecessary_null_comparison
      } else {
        setState(() {
          _localPassageiro = position;
        });
        _statusUberNaoChamado();
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcadorPassageiro(Position local) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "imagens/passageiro.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorPassageiro = Marker(
          markerId: const MarkerId("marcador-passageiro"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: const InfoWindow(title: "Meu local"),
          icon: icone);

      setState(() {
        _marcadores.add(marcadorPassageiro);
      });
    });
  }

  _chamarUber() async {
    String enderecoDestino = _controllerDestino.text;

    if (enderecoDestino.isNotEmpty) {
      List<Location> listaEnderecos =
          await locationFromAddress(enderecoDestino);

      if (listaEnderecos.isNotEmpty) {
        Location endereco = listaEnderecos[0];

        List<Placemark> placemarks = await placemarkFromCoordinates(
            endereco.latitude, endereco.longitude);

        Destino destino = Destino();
        destino.cidade = placemarks[0].administrativeArea!;
        destino.cep = placemarks[0].postalCode!;
        destino.bairro = placemarks[0].subLocality!;
        destino.rua = placemarks[0].thoroughfare!;
        destino.numero = placemarks[0].subThoroughfare!;

        destino.latitude = endereco.latitude;
        destino.longitude = endereco.longitude;

        String enderecoConfirmacao;
        enderecoConfirmacao = "\n Cidade: ${destino.cidade}";
        enderecoConfirmacao += "\n Rua: ${destino.rua}, ${destino.numero}";
        enderecoConfirmacao += "\n Bairro: ${destino.bairro}";
        enderecoConfirmacao += "\n Cep: ${destino.cep}";

        // ignore: use_build_context_synchronously
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Confirmação do endereço"),
                content: Text(enderecoConfirmacao),
                contentPadding: const EdgeInsets.all(16),
                actions: <Widget>[
                  TextButton(
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  TextButton(
                    child: const Text(
                      "Confirmar",
                      style: TextStyle(color: Colors.green),
                    ),
                    onPressed: () {
                      //salvar requisicao
                      _salvarRequisicao(destino);

                      Navigator.pop(context);
                    },
                  )
                ],
              );
            });
      }
    }
  }

  _salvarRequisicao(Destino destino) async {
    /*

    + requisicao
      + ID_REQUISICAO
        + destino (rua, endereco, latitude...)
        + passageiro (nome, email...)
        + motorista (nome, email..)
        + status (aguardando, a_caminho...finalizada)

    * */

    Usuario passageiro = (await UsuarioFirebase.getDadosUsuarioLogado());
    passageiro.latitude = _localPassageiro.latitude;
    passageiro.longitude = _localPassageiro.longitude;

    Requisicao requisicao = Requisicao();
    requisicao.destino = destino;
    requisicao.passageiro = passageiro;
    requisicao.status = StatusRequisicao.AGUARDANDO;

    FirebaseFirestore db = FirebaseFirestore.instance;

    db.collection("requisicoes").doc(requisicao.id).set(requisicao.toMap());

    //Salvar requisição ativa
    Map<String, dynamic> dadosRequisicaoAtiva = {};
    dadosRequisicaoAtiva["id_requisicao"] = requisicao.id;
    dadosRequisicaoAtiva["id_usuario"] = passageiro.idUsuario;
    dadosRequisicaoAtiva["status"] = StatusRequisicao.AGUARDANDO;

    db
        .collection("requisicao_ativa")
        .doc(passageiro.idUsuario)
        .set(dadosRequisicaoAtiva);

    // ignore: unnecessary_null_comparison
    if (_streamSubscriptionRequisicoes == null) {
      //Adicionar listener requisicao
      _adicionarListenerRequisicao(requisicao.id);
    }
  }

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _statusUberNaoChamado() {
    _exibirCaixaEnderecoDestino = true;

    _alterarBotaoPrincipal("Chamar uber", const Color(0xff1ebbd8), _chamarUber);

    // ignore: unnecessary_null_comparison
    if (_localPassageiro != null) {
      Position position = Position(
          latitude: _localPassageiro.latitude,
          longitude: _localPassageiro.longitude,
          timestamp: null,
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0);

      _exibirMarcadorPassageiro(position);
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);

      _movimentarCamera(cameraPosition);
    }
  }

  _statusAguardando() {
    _exibirCaixaEnderecoDestino = false;

    _alterarBotaoPrincipal("Cancelar", Colors.red, _cancelarUber);

    double passageiroLat = _dadosRequisicao["passageiro"]["latitude"];
    double passageiroLon = _dadosRequisicao["passageiro"]["longitude"];

    Position position = Position(
        latitude: _localPassageiro.latitude,
        longitude: _localPassageiro.longitude,
        timestamp: null,
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0);

    _exibirMarcadorPassageiro(position);
    CameraPosition cameraPosition =
        CameraPosition(target: LatLng(passageiroLat, passageiroLon), zoom: 19);

    _movimentarCamera(cameraPosition);
  }

  _exibirDoisMarcadores(Marcador marcadorOrigem, Marcador marcadorDestino) {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    LatLng latLngOrigem = marcadorOrigem.local!;
    LatLng latLngDestino = marcadorDestino.local!;

    Set<Marker> listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            marcadorOrigem.caminhoImagem!)
        .then((BitmapDescriptor icone) {
      Marker mOrigem = Marker(
          markerId: MarkerId(marcadorOrigem.caminhoImagem!),
          position: LatLng(latLngOrigem.latitude, latLngOrigem.longitude),
          infoWindow: InfoWindow(title: marcadorOrigem.titulo),
          icon: icone);
      listaMarcadores.add(mOrigem);
    });

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            marcadorDestino.caminhoImagem!)
        .then((BitmapDescriptor icone) {
      Marker mDestino = Marker(
          markerId: MarkerId(marcadorDestino.caminhoImagem!),
          position: LatLng(latLngDestino.latitude, latLngDestino.longitude),
          infoWindow: InfoWindow(title: marcadorDestino.titulo),
          icon: icone);
      listaMarcadores.add(mDestino);
    });

    setState(() {
      _marcadores = listaMarcadores;
    });
  }

  _statusACaminho() {
    _exibirCaixaEnderecoDestino = false;

    _alterarBotaoPrincipal("Motorista a caminho", Colors.grey, () {});

    double latitudePassageiro = _dadosRequisicao["passageiro"]["latitude"];
    double longitudePassageiro = _dadosRequisicao["passageiro"]["longitude"];

    double latitudeMotorista = _dadosRequisicao["motorista"]["latitude"];
    double longitudeMotorista = _dadosRequisicao["motorista"]["longitude"];

    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeMotorista, longitudeMotorista),
        "imagens/motorista.png",
        "Local motorista");

    Marcador marcadorDestino = Marcador(
        LatLng(latitudePassageiro, longitudePassageiro),
        "imagens/passgeiro.png",
        "Local destino");

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);
  }

  _statusEmViagem() {
    _exibirCaixaEnderecoDestino = false;

    _alterarBotaoPrincipal("Em viagem", Colors.grey, () {});

    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];

    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];

    Marcador marcadorOrigem = Marcador(LatLng(latitudeOrigem, longitudeOrigem),
        "imagens/motorista.png", "Local motorista");

    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino, longitudeDestino),
        "imagens/destino.png",
        "Local destino");

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);
  }

  _exibirCentralizarDoisMarcadores(
      Marcador marcadorOrigem, Marcador marcadorDestino) {
    double latitudeOrigem = marcadorOrigem.local!.latitude;
    double longitudeOrigem = marcadorOrigem.local!.longitude;

    double latitudeDestino = marcadorDestino.local!.latitude;
    double longitudeDestino = marcadorDestino.local!.longitude;

    //Exibir dois marcadores
    _exibirDoisMarcadores(marcadorOrigem, marcadorDestino);

    double nLat, nLon, sLat, sLon;

    if (latitudeOrigem <= latitudeDestino) {
      sLat = latitudeOrigem;
      nLat = latitudeDestino;
    } else {
      sLat = latitudeDestino;
      nLat = latitudeOrigem;
    }

    if (longitudeOrigem <= longitudeDestino) {
      sLon = longitudeOrigem;
      nLon = longitudeDestino;
    } else {
      sLon = longitudeDestino;
      nLon = longitudeOrigem;
    }

    _movimentarCameraBounds(LatLngBounds(
        northeast: LatLng(nLat, nLon), southwest: LatLng(sLat, sLon)));
  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 100));
  }

  _cancelarUber() async {
    final firebaseUser = await UsuarioFirebase.getUsuarioAtual();

    FirebaseFirestore db = FirebaseFirestore.instance;
    db
        .collection("requisicoes")
        .doc(_idRequisicao)
        .update({"status": StatusRequisicao.CANCELADA}).then((_) {
      db.collection("requisicao_ativa").doc(firebaseUser.uid).delete();
    });

    //_idRequisicao = dados["id_requisicao"];
  }

  _recuperarRequisicaoAtiva() async {
    final firebaseUser = await UsuarioFirebase.getUsuarioAtual();

    FirebaseFirestore db = FirebaseFirestore.instance;
    // ignore: await_only_futures
    DocumentSnapshot documentSnapshot =
        await db.collection("requisicao_ativa").doc(firebaseUser.uid).get();

    // ignore: unnecessary_null_comparison
    if (documentSnapshot.data != null) {
      Map<String, dynamic> dados =
          documentSnapshot.data() as Map<String, dynamic>;
      _dadosRequisicao = dados;
      _idRequisicao = dados["id_requisicao"];
      _adicionarListenerRequisicao(_idRequisicao!);
    } else {
      _statusUberNaoChamado();
    }
  }

  _adicionarListenerRequisicao(String idRequisicao) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    // ignore: await_only_futures
    _streamSubscriptionRequisicoes = await db
        .collection("requisicoes")
        .doc(idRequisicao)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic>? dados =
            (snapshot.exists) ? snapshot.data() : null;
        String status = dados!["status"];
        _idRequisicao = dados["id_requisicao"];

        switch (status) {
          case StatusRequisicao.AGUARDANDO:
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO:
            _statusACaminho();
            break;
          case StatusRequisicao.VIAGEM:
            _statusEmViagem();
            break;
          case StatusRequisicao.FINALIZADA:
            break;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _recuperarRequisicaoAtiva();

    //_recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel passageiro"),
        actions: [
          PopupMenuButton<String>(
            onSelected: _escolhaMenuItem,
            itemBuilder: (context) {
              return itensMenu.map((String item) {
                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList();
            },
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _posicaoCamera,
            onMapCreated: _onMapCreated,
            // myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _marcadores,
          ),
          Visibility(
              visible: _exibirCaixaEnderecoDestino,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white),
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                              // ignore: sized_box_for_whitespace
                              icon: Container(
                                margin:
                                    const EdgeInsets.only(left: 20, bottom: 10),
                                width: 10,
                                height: 10,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.green,
                                ),
                              ),
                              hintText: "Meu local",
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(
                                  left: 15, top: 16, bottom: 10)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 55,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white),
                        child: TextField(
                          controller: _controllerDestino,
                          decoration: InputDecoration(
                              // ignore: sized_box_for_whitespace
                              icon: Container(
                                margin:
                                    const EdgeInsets.only(left: 20, bottom: 10),
                                width: 10,
                                height: 10,
                                child: const Icon(
                                  Icons.local_taxi,
                                  color: Colors.black,
                                ),
                              ),
                              hintText: "Digite o destino",
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(
                                  left: 15, top: 16, bottom: 10)),
                        ),
                      ),
                    ),
                  ),
                ],
              )),
          Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: Platform.isIOS
                    ? const EdgeInsets.fromLTRB(20, 10, 20, 25)
                    : const EdgeInsets.all(10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _corBotao,
                      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16)),
                  onPressed: () {
                    _funcaoBotao();
                  },
                  child: Text(
                    _textoBotao,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ))
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _streamSubscriptionRequisicoes.cancel();
  }
}
