// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:mobile_device_identifier/mobile_device_identifier.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv_indoor/app/controllers/noticias_controller.dart';
import 'package:tv_indoor/app/controllers/tv_indoor_controller.dart';
import 'package:tv_indoor/app/controllers/webview_controller.dart';
import 'package:tv_indoor/app/utils/globals.dart';
import 'package:tv_indoor/app/utils/media_cache_manager.dart';

class ConfigController extends GetxController {
  
  final RxString deviceId = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool loadingMidias = false.obs;
  final RxMap<String, dynamic> deviceData = <String, dynamic>{}.obs;
  final RxList<RxMap<String, dynamic>> midiasCache = <RxMap<String, dynamic>>[].obs;
  final RxString versao = ''.obs;
  
  final baseUrl = kDebugMode ? dotenv.env['BASE_URL_PROD'] : dotenv.env['BASE_URL_PROD'];
  final apiKey = dotenv.env['API_KEY'];

  final dio = Dio();
  final CacheManager _mediaCache = MediaCacheManager();

  double get totalProgress {
    if (midiasCache.isEmpty) return 0.0;
    final sum = midiasCache
        .map((e) => e['progress'] as double)
        .fold(0.0, (a, b) => a + b);
    return sum / midiasCache.length;
  }

  bool get allDone => midiasCache.every((e) => (e['progress'] as double) >= 1.0);



  @override
  Future<void> onInit() async {
    super.onInit();
    deviceId.value = (await getDeviceId())!;
    await autenticarDispositivo();
  }

  void reset() {
    print('resetando');
    isLoading.value = true;
    deviceId.value = '';
    midiasCache.clear();
    midiasCache.clear();
    onInit();

  }


  Future<String?> getDeviceId() async{
    return await MobileDeviceIdentifier().getDeviceId(); 
  }

Future<void> fetchData() async {
  final prefs = await SharedPreferences.getInstance();

  try {
    final response = await dio.get(
      '$baseUrl/dispositivo/${deviceId.value}',
      options: Options(
        headers: {'Authorization': 'Bearer $apiKey'},
        // status ≥ 500 não lança exceção ―‐ cuidaremos abaixo
        validateStatus: (code) => code != null && code < 500,
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      deviceData.value = response.data;          // ✅ ok
    } else {
      // resposta 404/500 ou corpo nulo
      deviceData.clear();                        // 👈 nada novo
      debugPrint('⚠️ Backend status ${response.statusCode}');
    }
  } on DioException catch (e) {
    // timeout, perda de rede, etc. → só registra, sem rethrow
    debugPrint('⚠️ Erro de rede: $e');
    deviceData.clear();                          // mantém cache antigo
  }
}
  Future<void> autenticarDispositivo() async {
    try {

      isLoading.value = true;
      await fetchData();
      configurado.value = deviceData['configurado']; 

      iniciaTimer(deviceData['dispositivo']['tempo_atualizacao']);
      await saveCotacoes();
      await saveNoticias();
      await savePrevisaoTempo();
      await saveCotMetais();
      if(configurado.isTrue) {
        
        await handleMidias(deviceData['midias']);
        Get.back();

        if(loadingMidias.isFalse){
          Get.offAllNamed('/tv-indoor');
        }
      }
    } catch (e) {
      print(e);
    } finally {
      isLoading.value = false;
    }
    
  }
  

  Future<void> iniciaTimer(int minutos) async {
    print('print minutos: $minutos');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('tempo_atualizacao', minutos.toString());
  }

  Future<bool> refreshData() async {
    try {

      isLoading.value = true;
      await fetchData();
      final existeMidiasDiferentes = await verificarMidiasAlteradas();

      configurado.value = deviceData['configurado']; 
      iniciaTimer(deviceData['dispositivo']['tempo_atualizacao']);
      await saveCotacoes();
      await saveNoticias();
      if(existeMidiasDiferentes) {
        await handleMidias(deviceData['midias']);
        Get.back();
      }
      isLoading.value = false;
      return existeMidiasDiferentes;

    } catch (e) {
      print(e);
      return false;
    }

  }



  Future<void> saveCotacoes() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      var cotacoes = deviceData['cotacoes'];
      print('print cotacoes: $cotacoes');
      prefs.setString('cotacoes', jsonEncode(cotacoes));
      WebviewController webviewController = Get.find<WebviewController>();
      webviewController.getCotacoes();
  }

  Future<void> savePrevisaoTempo() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      var cotacoes = deviceData['previsao_tempo'];
      print('print cotacoes $cotacoes');
      prefs.setString('previsao_tempo', jsonEncode(cotacoes));
      WebviewController webviewController = Get.find<WebviewController>();
      webviewController.getPrevisao();
  }

  Future<void> saveCotMetais() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      var metais = deviceData['cotacao_metais'];
      prefs.setString('cotacao_metais', jsonEncode(metais));
      WebviewController webviewController = Get.find<WebviewController>();
      webviewController.getMetais();
  }

  Future<void> saveNoticias() async {

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      var noticias = deviceData['noticias'];
      prefs.setString('noticias', jsonEncode(noticias));
      NoticiasController noticiasController = Get.find<NoticiasController>();
      noticiasController.getNoticias();

  }

  Future<void> handleMidias(List<dynamic> rawMidias) async {
    // (A) ──────────────────────────────────────────────────────────────
    // 1. Zere a lista em memória para não acumular duplicatas
    midiasCache.clear();

    // 2. Limpe (em disco) arquivos que não estão mais na API ───────────
    final apiUrls = rawMidias.map((m) => m['url'] as String).toSet();
    final prefs   = await SharedPreferences.getInstance();
    final stored  = prefs.getString('midias');
    if (stored != null) {
      final storedList = jsonDecode(stored) as List;
      final toRemove   = storedList
          .where((m) => !apiUrls.contains(m['url'] as String))
          .toList();

      print(toRemove);
      for (final rm in toRemove) {
        await _mediaCache.removeFile(rm['url'] as String);
      }
    }

    // 3. Mostre o diálogo de progresso antes de começar a baixar ───────
    showDownloadProgress();
    loadingMidias.value = true;

    // (B) ──────────────────────────────────────────────────────────────
    // 4. Baixe as mídias com barra de progresso
    final downloadFutures = <Future<void>>[];

    for (final m in rawMidias) {
      final entrada = <String, dynamic>{
        'tipo'    : m['tipo'],
        'url'     : m['url'],
        'file'    : null,
        'progress': 0.0,
      }.obs;
      midiasCache.add(entrada);

      final c = Completer<void>();
      downloadFutures.add(c.future);

      _mediaCache.getFileStream(m['url'], withProgress: true).listen((resp) {
        if (resp is DownloadProgress) {
          final pct = resp.totalSize != null
              ? resp.downloaded / resp.totalSize!
              : 0.0;
          entrada['progress'] = pct;
          entrada.refresh();
        } else if (resp is FileInfo) {
          entrada['file']     = resp.file.path;
          entrada['progress'] = 1.0;
          entrada.refresh();
          c.complete();
        }
      });
    }

    await Future.wait(downloadFutures);

    // (C) ──────────────────────────────────────────────────────────────
    // 5. Gere lista "limpa" (sem progress, sem Rx) p/ gravar no prefs
    final listaParaPrefs = [
      for (final rx in midiasCache)
        {
          'tipo': rx['tipo'],
          'url' : rx['url'],
          'file': rx['file'],     // path definitivo
        }
    ];
    await prefs.setString('midias', jsonEncode(listaParaPrefs));

    // 6. Feche diálogo e sinalize fim
    loadingMidias.value = false;
    Get.back();                       // fecha o AlertDialog de download
  }

  // Future<void> handleMidias(List<dynamic> rawMidias) async {

  //   midiasCache.clear();
  //   final Set<String> apiUrls = rawMidias
  //     .map((m) => m['url'] as String)
  //     .toSet();

  //   final SharedPreferences prefs = await SharedPreferences.getInstance();

  //   final items =  prefs.getString('midias');
  //   if(items != null) {
  //     final itemsDecoded = jsonDecode(items) as List;
    
  //     final toRemove = itemsDecoded
  //       .where((m) => !apiUrls.contains(m['url'] as String))
  //       .toList();  // <— materializa
        
  //     print('remover: $toRemove');

  //     for (final rm in toRemove) {
  //       final url = rm['url'] as String;
  //       await _mediaCache.removeFile(url);
  //       itemsDecoded.removeWhere((e) => e['url'] == url);
  //     }

  //     prefs.setString('midias', jsonEncode(itemsDecoded));
  //     showDownloadProgress();
  //   }
    
  //   loadingMidias.value = true;

  //   final futures = <Future<void>>[];

  //   for (var m in rawMidias) {
  //     final url   = m['url']   as String;
  //     final tipo  = m['tipo']  as String;

  //     // 1) Cria o RxMap e adiciona na RxList
  //     final entrada = <String, dynamic>{
  //       'tipo': tipo,
  //       'url': url,
  //       'file': null,
  //       'progress': 0.0,
  //     }.obs;

  //     midiasCache.add(entrada);

  //     // cria um Completer que vamos completar no evento FileInfo
  //     final completer = Completer<void>();
  //     futures.add(completer.future);

  //     // 2) Pega o stream de download com progresso
  //     final stream = _mediaCache.getFileStream(url, withProgress: true);

  //     // 3) Escuta o stream

  //     stream.listen((resp) {
  //       if (resp is DownloadProgress) {
  //         final pct = resp.totalSize != null
  //             ? resp.downloaded / resp.totalSize!
  //             : 0.0;
  //         entrada['progress'] = pct;
  //         entrada.refresh();

  //       } else if (resp is FileInfo) 
  //       {
  //         entrada['file'] = resp.file.path;
  //         entrada['progress'] = 1.0;
  //         entrada.refresh();
  //         completer.complete();  
  //                 // sinaliza que esse download acabou
  //       }
  //     });
  //   }

  //   await Future.wait(futures);
  //   prefs.setString('midias', jsonEncode(midiasCache));
  //   loadingMidias.value = false;
  //   return;

  // }

  //SEMPRE QUE CHAMAR, CERTIFICAR DE CHAMAR FETCH DATA ANTES
  Future<bool> verificarMidiasAlteradas() async {

    // 2) Extrai lista de URLs da API
    final List<dynamic> apiMidias = deviceData['midias'] as List<dynamic>;
    final Set<String> apiUrls = apiMidias
        .map((m) => m['url'] as String)
        .toSet();

    // 3) Busca o JSON armazenado em SharedPreferences
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storedJson = prefs.getString('midias');

    // Se não houver nada armazenado, considera alteração se a API retornar alguma mídia
    if (storedJson == null) {
      return apiUrls.isNotEmpty;
    }

    // 4) Decodifica o JSON salvo e extrai as URLs
    final List<dynamic> storedList = jsonDecode(storedJson) as List<dynamic>;
    final Set<String> storedUrls = storedList
        .map((m) => (m as Map<String, dynamic>)['url'] as String)
        .toSet();

    // 5) Compara os dois conjuntos de URLs
    // setEquals vem de 'package:flutter/foundation.dart'
    return !setEquals(apiUrls, storedUrls);
  }


  void showDownloadProgress() {
    Get.dialog(
      AlertDialog(
        title: const Text('Baixando mídias'),
        content: SizedBox(
          width: 400,
          height: 50, // espaço suficiente
          child: Obx(() {
            // pega o total agregado
            final pct = totalProgress;
            final label = allDone
              ? 'Concluído!'
              : 'Baixando mídias: ${(pct * 100).toStringAsFixed(0)}%';
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: pct),
              ],
            );
          }),
        ),
      ),
      barrierDismissible: false,
    );
  }

}