import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv_indoor/app/controllers/config_controller.dart';
import 'package:tv_indoor/app/controllers/webview_controller.dart';
import 'package:tv_indoor/app/screens/widgets/table_widget.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';


class SideBar extends StatelessWidget {

  final WebviewController controller = Get.put(WebviewController());
  
  SideBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Container(
        clipBehavior: Clip.none,
        width: 250,
        height: double.infinity,
        decoration: const BoxDecoration(
          // borderRadius: BorderRadiusDirectional.only(),
          color:  Color.fromRGBO(51, 91, 64, 1.0),
        ),
        child: 
            Column(   
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Image.asset(
                            'assets/logos/Logo Rayquimica-1.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20,),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 100,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Card(                             
                            elevation: 3,
                            clipBehavior: Clip.antiAlias,                          
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),            
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black,
                                    Colors.grey.shade900,
                                    Colors.grey.shade800,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        if(controller.previsaoTempo.isEmpty) ... [
                                          const Expanded(
                                            child: Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          )
                                        ] else ... [
                                          // Bloco de ícone, temperatura e descrição
                                          Builder(builder: (_) {
                                            final previsao = controller.previsaoTempo;
                                            final icone = previsao['icone'] as String?;
                                            final temp = previsao['temperatura_c'] as num?;
                                            final desc = previsao['descricao'] as String?;
                                            if (icone == null || temp == null || desc == null) {
                                              return const Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              );
                                            }
                                            return Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                        children: [
                                                          controller.svgAnimado(icone),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            '${temp.toDouble().toStringAsFixed(1)} °C',
                                                            style: const TextStyle(
                                                              fontSize: 20,
                                                              height: 1,
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      // const SizedBox(height: 4),
                                                      Text(
                                                        desc,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          letterSpacing: 1,
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        softWrap: true,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }),
                                          // Bloco de vento
                                          Expanded(
                                            child: Builder(builder: (_) {
                                              final previsao = controller.previsaoTempo;
                                              final icVent = previsao['icone_vento'] as String?;
                                              final vento = previsao['vento_kmh'] as num?;
                                              if (icVent == null || vento == null) {
                                                // sem dados de vento, esconde o widget
                                                return const SizedBox.shrink();
                                              }
                                              return Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const BoxedIcon(
                                                    WeatherIcons.strong_wind,  // ícone de vento
                                                    size: 20,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${vento.toDouble().toStringAsFixed(1)} KM/H',
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }),
                                          ),
                                        ]
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30,),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 80,
                          child: Row(
                            children: [
                              if(controller.loading.isTrue) ... [
                                const Expanded(
                                  child:  Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              ] else ... [
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(5),
                                    itemCount: controller.cotacoes.length,
                                    itemBuilder: (context, index) {
                                      
                                      final c = controller.cotacoes[index];
                          
                                      final arrow = c['variation'] >= 0 ? '▲' : '▼';
                                      final color = c['variation'] >= 0 ? Colors.green : Colors.red;
                          
                                      return Card(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        elevation: 3,
                                        child: ListTile(
                                          minTileHeight: 50,
                                          minLeadingWidth: 10,
                                          horizontalTitleGap: 10,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                          leading:  c['symbol'] == null
                                          ? const Icon(Icons.currency_bitcoin, size: 18)
                                          : Text(
                                            c['symbol'],
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                          title: Text(
                                            '${c['code']} • R\$ ${c['rate'].toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                          trailing: Text(
                                            '$arrow ${c['variation'].abs().toStringAsFixed(2)}%',
                                            style: TextStyle(color: color, fontSize: 10),
                                          ),
                                          subtitle: Text(
                                            c['updatedAt'],
                                            softWrap: false,
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                                          ),
                                        ),
                                      );
                                    },
                                  
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                      // const SizedBox(height: 30,),
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CotacaoTable(),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment:  MainAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'V${controller.versao.value}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
        );
    });
  }
}