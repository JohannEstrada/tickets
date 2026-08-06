import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class RegistrarInventarioDialog extends StatefulWidget {
  const RegistrarInventarioDialog({super.key});

  @override
  State<RegistrarInventarioDialog> createState() =>
      _RegistrarInventarioDialogState();
}

class _RegistrarInventarioDialogState extends State<RegistrarInventarioDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _personalController;
  late final TextEditingController _marcaController;
  late final TextEditingController _modeloController;
  late final TextEditingController _resguardoController;
  late final TextEditingController _patrimonioController;
  late final TextEditingController _serieController;
  late final TextEditingController _descripcionAdicionalController;
  late final TextEditingController _ipController;
  late final TextEditingController _macController;
  late final TextEditingController _observacionesController;

  final String _selectedLineaBien = 'Cómputo y telefonía';
  String? _selectedTipoBien;
  String? _selectedEstatus;
  String? _selectedTipoRam;
  String? _selectedMemoriaRam;
  String? _selectedVelocidadRam;
  String? _selectedTipoDd;
  String? _selectedCapacidadDd;
  String? _selectedProcesador;
  String? _selectedSistemaOperativo;
  String? _selectedVersionSo;

  final List<String> _opcionesTipoBien = [
    'TELEFONO',
    'CPU',
    'MONITOR',
    'NO BREAK',
    'SWITCH',
    'ROUTER',
    'SERVIDOR',
    'LAPTOP',
  ];

  final List<String> _opcionesEstatus = ['BUENO', 'MALO', 'REGULAR'];

  final List<String> _opcionesTipoRam = [
    'DDR',
    'DDR2',
    'DDR3',
    'DDR4',
    'DDR5',
    'No aplica',
  ];

  final List<String> _opcionesMemoriaRam = [
    '4GB',
    '8GB',
    '16GB',
    '32GB',
    '64GB',
    'No aplica',
  ];

  final List<String> _opcionesVelocidadRam = [
    '1066MHz',
    '1333 MHz',
    '1600 MHz',
    '2400 MHz',
    '3200 MHz',
    'No aplica',
  ];

  final List<String> _opcionesTipoDd = [
    'HDD',
    'SDD',
    'NVMe',
    'eMMC',
    'No aplica',
  ];

  final List<String> _opcionesCapacidadDd = [
    '128 GB',
    '256 GB',
    '512 GB',
    '1 TB',
    '2 TB',
    '4 TB',
    'No aplica',
  ];

  final List<String> _opcionesProcesador = [
    'Intel i3',
    'Intel i5',
    'Intel i7',
    'Intel i9',
    'AMD Ryzen 3',
    'AMD Ryzen 5',
    'AMD Ryzen 7',
    'No aplica',
  ];

  final List<String> _opcionesSistemaOperativo = [
    'Windows',
    'MacOS',
    'Linux',
    'Android',
    'No aplica',
  ];

  final List<String> _opcionesVersionSo = [
    'Win 10',
    'Win 11',
    'MacOS Sonoma',
    'MacOS Ventura',
    'Ubuntu',
    'Otro',
    'No aplica',
  ];

  bool _isSearchingPersonal = false;
  String? _personalErrorText;

  bool get _mostrarConectividad {
    if (_selectedTipoBien == 'TELEFONO') return true;
    if (_selectedTipoBien == 'CPU') return true;
    if (_selectedTipoBien == 'MONITOR') return false;
    if (_selectedTipoBien == 'NO BREAK') return false;
    if (_selectedTipoBien == 'SWITCH') return true;
    if (_selectedTipoBien == 'ROUTER') return true;
    if (_selectedTipoBien == 'SERVIDOR') return true;
    if (_selectedTipoBien == 'LAPTOP') return true;
    return false;
  }

  bool get _mostrarCaracteristicas {
    if (_selectedTipoBien == 'TELEFONO') return false;
    if (_selectedTipoBien == 'CPU') return true;
    if (_selectedTipoBien == 'MONITOR') return false;
    if (_selectedTipoBien == 'NO BREAK') return false;
    if (_selectedTipoBien == 'SWITCH') return false;
    if (_selectedTipoBien == 'ROUTER') return false;
    if (_selectedTipoBien == 'SERVIDOR') return true;
    if (_selectedTipoBien == 'LAPTOP') return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _personalController = TextEditingController();
    _personalController.addListener(_onPersonalChanged);
    _marcaController = TextEditingController();
    _modeloController = TextEditingController();
    _resguardoController = TextEditingController();
    _patrimonioController = TextEditingController();
    _serieController = TextEditingController();
    _descripcionAdicionalController = TextEditingController();
    _ipController = TextEditingController();
    _macController = TextEditingController();
    _observacionesController = TextEditingController();
  }

  void _onPersonalChanged() {
    if (_personalErrorText != null) {
      setState(() {
        _personalErrorText = null;
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _personalController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _resguardoController.dispose();
    _patrimonioController.dispose();
    _serieController.dispose();
    _descripcionAdicionalController.dispose();
    _ipController.dispose();
    _macController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String mensaje, {Color color = Colors.red}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<String?> _obtenerEmpleadoPorRFC(String rfc) async {
    final url = Uri.parse(
      'http://187.216.141.163:8080/api_siarh/api_info_empleado.php',
    );
    debugPrint('📤 [API INFO EMPLEADO] POST a: $url');
    debugPrint(
      '📦 [API INFO EMPLEADO] Body: {"action": "get_empleado", "rfc": "${rfc.trim().toUpperCase()}"}',
    );
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'action': 'get_empleado',
          'rfc': rfc.trim().toUpperCase(),
        }),
      );

      debugPrint(
        '📥 [API INFO EMPLEADO] Código de respuesta: ${response.statusCode}',
      );
      debugPrint(
        '📥 [API INFO EMPLEADO] Cuerpo de respuesta: ${response.body}',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final Map<String, dynamic> data = responseData['data'];
          final String nombre = data['NOMBRE'] ?? '';
          final String appat = data['APELLIDO PATERNO'] ?? '';
          final String apmat = data['APELLIDO MATERNO'] ?? '';
          final String nombreCompleto = '$nombre $appat $apmat'
              .trim()
              .toUpperCase();
          debugPrint(
            '✅ [API INFO EMPLEADO] Empleado encontrado: $nombreCompleto',
          );
          return nombreCompleto;
        } else {
          debugPrint(
            '⚠️ [API INFO EMPLEADO] Éxito falso o sin datos: $responseData',
          );
        }
      } else {
        debugPrint(
          '❌ [API INFO EMPLEADO] Falló con estado: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('🔥 [API INFO EMPLEADO] Error de conexión: $e');
    }
    return null;
  }

  Future<void> _buscarPorRFC(String rfc) async {
    debugPrint('🔍 [BUSCAR POR RFC] Iniciando búsqueda para: "$rfc"');
    if (_isSearchingPersonal) {
      debugPrint(
        '⚠️ [BUSCAR POR RFC] Ya hay una búsqueda en progreso, ignorando...',
      );
      return;
    }
    setState(() {
      _isSearchingPersonal = true;
      _personalErrorText = null;
    });
    final nombreCompleto = await _obtenerEmpleadoPorRFC(rfc);
    setState(() {
      _isSearchingPersonal = false;
      if (nombreCompleto != null) {
        _personalController.text = nombreCompleto;
        _personalErrorText = null;
        _mostrarMensaje(
          'Empleado encontrado: $nombreCompleto',
          color: Colors.green,
        );
      } else {
        debugPrint(
          '❌ [BUSCAR POR RFC] No se obtuvo ningún empleado para el RFC: "$rfc"',
        );
        _personalErrorText = 'RFC no encontrado, verifique de nuevo...';
        _mostrarMensaje('No se encontró personal con ese RFC');
      }
    });
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0A2E5C), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildThemeSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0A2E5C), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade200, height: 1, thickness: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Registrar Equipo a Inventario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A2E5C),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // TEMA 1: Personal asignado
                _buildThemeSection(
                  icon: Icons.person_outline_rounded,
                  title: 'Selecciona el personal al que se le asigna el equipo',
                  children: [
                    const Text(
                      'PERSONAL ASIGNADO *',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _personalController,
                      style: const TextStyle(fontSize: 13),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(10)],
                      readOnly: _personalController.text.length > 10,
                      onChanged: (value) {
                        final rfc = value.trim();
                        if (rfc.length == 10) {
                          _buscarPorRFC(rfc);
                        }
                      },
                      decoration:
                          _inputDecoration(
                            'Busque por RFC sin homoclave...',
                          ).copyWith(
                            errorText: _personalErrorText,
                            suffixIcon: _isSearchingPersonal
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Color(0xFF0A2E5C),
                                            ),
                                      ),
                                    ),
                                  )
                                : _personalController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      color: Colors.grey,
                                    ),
                                    tooltip: 'Limpiar',
                                    onPressed: () {
                                      _personalController.clear();
                                    },
                                  )
                                : null,
                          ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor escriba o busque el personal asignado';
                        }
                        if (_personalErrorText != null) {
                          return _personalErrorText;
                        }
                        return null;
                      },
                    ),
                  ],
                ),

                // TEMA 2: Selección de tipo de bien
                _buildThemeSection(
                  icon: Icons.devices_rounded,
                  title: 'Selección del tipo de bien y descripción adicional',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LÍNEA DE BIEN *',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                initialValue: _selectedLineaBien,
                                readOnly: true,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _inputDecoration(
                                  '',
                                ).copyWith(fillColor: Colors.grey.shade100),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TIPO DE BIEN *',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _selectedTipoBien,
                                dropdownColor: Colors.white,
                                icon: const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: Color(0xFF0A2E5C),
                                  size: 28,
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 13,
                                ),
                                decoration: _inputDecoration(
                                  'Seleccione tipo de bien...',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Por favor seleccione el tipo';
                                  }
                                  return null;
                                },
                                items: _opcionesTipoBien.map((String tipo) {
                                  return DropdownMenuItem<String>(
                                    value: tipo,
                                    child: Text(tipo),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedTipoBien = value;

                                    if (!_mostrarConectividad) {
                                      _ipController.clear();
                                      _macController.clear();
                                    }

                                    if (!_mostrarCaracteristicas) {
                                      _selectedTipoRam = null;
                                      _selectedMemoriaRam = null;
                                      _selectedVelocidadRam = null;
                                      _selectedTipoDd = null;
                                      _selectedCapacidadDd = null;
                                      _selectedProcesador = null;
                                      _selectedSistemaOperativo = null;
                                      _selectedVersionSo = null;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'DESCRIPCIÓN ADICIONAL (OPCIONAL)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descripcionAdicionalController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration(
                        'Escriba una descripción opcional...',
                      ),
                    ),
                  ],
                ),

                // TEMA 3: Información de Control
                _buildThemeSection(
                  icon: Icons.fact_check_outlined,
                  title:
                      'Información de Control (Identificación física y estado)',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MARCA *',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _marcaController,
                                style: const TextStyle(fontSize: 13),
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: _inputDecoration(
                                  'Escriba la marca...',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Por favor escriba la marca';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MODELO *',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _modeloController,
                                style: const TextStyle(fontSize: 13),
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: _inputDecoration(
                                  'Escriba el modelo...',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Por favor escriba el modelo';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NO. RESGUARDO *',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _resguardoController,
                                style: const TextStyle(fontSize: 13),
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: _inputDecoration(
                                  'Escriba el resguardo...',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Por favor escriba el resguardo';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'R. PATRIMONIO *',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _patrimonioController,
                                style: const TextStyle(fontSize: 13),
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: _inputDecoration(
                                  'Escriba el patrimonio...',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Por favor escriba el patrimonio';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NO. SERIE *',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _serieController,
                                style: const TextStyle(fontSize: 13),
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: _inputDecoration(
                                  'Escriba el número de serie...',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Por favor escriba el número de serie';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ESTATUS *',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _selectedEstatus,
                                dropdownColor: Colors.white,
                                icon: const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: Color(0xFF0A2E5C),
                                  size: 28,
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 13,
                                ),
                                decoration: _inputDecoration(
                                  'Seleccione estatus...',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Por favor seleccione el estatus';
                                  }
                                  return null;
                                },
                                items: _opcionesEstatus.map((String estatus) {
                                  return DropdownMenuItem<String>(
                                    value: estatus,
                                    child: Text(estatus),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedEstatus = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // TEMA 4: Información de conectividad (IP y MAC)
                if (_mostrarConectividad) ...[
                  _buildThemeSection(
                    icon: Icons.settings_ethernet_rounded,
                    title: 'Información de conectividad (IP y MAC)',
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DIRECCIÓN IP',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _ipController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: _inputDecoration(
                                    'Ej. 192.168.1.100...',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DIRECCIÓN MAC',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _macController,
                                  style: const TextStyle(fontSize: 13),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: _inputDecoration(
                                    'Ej. 00:1A:2B:3C:4D:5E...',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

                // TEMA 5: Características del equipo
                if (_mostrarCaracteristicas) ...[
                  _buildThemeSection(
                    icon: Icons.memory_rounded,
                    title:
                        'Características del equipo (RAM, almacenamiento, procesador, software)',
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TIPO RAM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _selectedTipoRam,
                                  dropdownColor: Colors.white,
                                  icon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Color(0xFF0A2E5C),
                                    size: 28,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 13,
                                  ),
                                  decoration: _inputDecoration(
                                    'Seleccione tipo...',
                                  ),
                                  items: _opcionesTipoRam.map((String tipo) {
                                    return DropdownMenuItem<String>(
                                      value: tipo,
                                      child: Text(tipo),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTipoRam = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MEMORIA RAM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _selectedMemoriaRam,
                                  dropdownColor: Colors.white,
                                  icon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Color(0xFF0A2E5C),
                                    size: 28,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 13,
                                  ),
                                  decoration: _inputDecoration(
                                    'Seleccione memoria...',
                                  ),
                                  items: _opcionesMemoriaRam.map((String ram) {
                                    return DropdownMenuItem<String>(
                                      value: ram,
                                      child: Text(ram),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedMemoriaRam = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'VELOCIDAD RAM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _selectedVelocidadRam,
                                  dropdownColor: Colors.white,
                                  icon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Color(0xFF0A2E5C),
                                    size: 28,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 13,
                                  ),
                                  decoration: _inputDecoration(
                                    'Seleccione velocidad...',
                                  ),
                                  items: _opcionesVelocidadRam.map((
                                    String vel,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: vel,
                                      child: Text(vel),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedVelocidadRam = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TIPO DD',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _selectedTipoDd,
                                  dropdownColor: Colors.white,
                                  icon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Color(0xFF0A2E5C),
                                    size: 28,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 13,
                                  ),
                                  decoration: _inputDecoration(
                                    'Seleccione tipo...',
                                  ),
                                  items: _opcionesTipoDd.map((String dd) {
                                    return DropdownMenuItem<String>(
                                      value: dd,
                                      child: Text(dd),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTipoDd = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CAPACIDAD DD',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _selectedCapacidadDd,
                                  dropdownColor: Colors.white,
                                  icon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Color(0xFF0A2E5C),
                                    size: 28,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 13,
                                  ),
                                  decoration: _inputDecoration(
                                    'Seleccione capacidad...',
                                  ),
                                  items: _opcionesCapacidadDd.map((String cap) {
                                    return DropdownMenuItem<String>(
                                      value: cap,
                                      child: Text(cap),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCapacidadDd = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PROCESADOR',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _selectedProcesador,
                                  dropdownColor: Colors.white,
                                  icon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Color(0xFF0A2E5C),
                                    size: 28,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 13,
                                  ),
                                  decoration: _inputDecoration(
                                    'Seleccione procesador...',
                                  ),
                                  items: _opcionesProcesador.map((String proc) {
                                    return DropdownMenuItem<String>(
                                      value: proc,
                                      child: Text(proc),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedProcesador = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SISTEMA OPERATIVO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _selectedSistemaOperativo,
                                  dropdownColor: Colors.white,
                                  icon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Color(0xFF0A2E5C),
                                    size: 28,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 13,
                                  ),
                                  decoration: _inputDecoration(
                                    'Seleccione sistema...',
                                  ),
                                  items: _opcionesSistemaOperativo.map((
                                    String so,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: so,
                                      child: Text(so),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSistemaOperativo = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'VERSIÓN SISTEMA OPERATIVO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _selectedVersionSo,
                                  dropdownColor: Colors.white,
                                  icon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Color(0xFF0A2E5C),
                                    size: 28,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 13,
                                  ),
                                  decoration: _inputDecoration(
                                    'Seleccione versión...',
                                  ),
                                  items: _opcionesVersionSo.map((String ver) {
                                    return DropdownMenuItem<String>(
                                      value: ver,
                                      child: Text(ver),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedVersionSo = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

                // TEMA 6: Anotaciones especiales
                _buildThemeSection(
                  icon: Icons.note_alt_rounded,
                  title: 'Anotaciones especiales',
                  children: [
                    const Text(
                      'OBSERVACIONES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _observacionesController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13),
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration(
                        'Escriba observaciones especiales del equipo...',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            debugPrint(
                              'Personal asignado guardado: ${_personalController.text}',
                            );
                            debugPrint(
                              'Línea de bien guardada: $_selectedLineaBien',
                            );
                            debugPrint(
                              'Tipo de bien guardado: $_selectedTipoBien',
                            );
                            debugPrint(
                              'Descripción adicional guardada: ${_descripcionAdicionalController.text}',
                            );
                            debugPrint(
                              'Marca guardada: ${_marcaController.text}',
                            );
                            debugPrint(
                              'Modelo guardado: ${_modeloController.text}',
                            );
                            debugPrint(
                              'Resguardo guardado: ${_resguardoController.text}',
                            );
                            debugPrint(
                              'R. Patrimonio guardado: ${_patrimonioController.text}',
                            );
                            debugPrint(
                              'No. Serie guardado: ${_serieController.text}',
                            );
                            debugPrint('Estatus guardado: $_selectedEstatus');
                            debugPrint(
                              'Dirección IP guardada: ${_ipController.text}',
                            );
                            debugPrint(
                              'Dirección MAC guardada: ${_macController.text}',
                            );
                            debugPrint('Tipo RAM guardado: $_selectedTipoRam');
                            debugPrint(
                              'Memoria RAM guardada: $_selectedMemoriaRam',
                            );
                            debugPrint(
                              'Velocidad RAM guardada: $_selectedVelocidadRam',
                            );
                            debugPrint('Tipo DD guardado: $_selectedTipoDd');
                            debugPrint(
                              'Capacidad DD guardada: $_selectedCapacidadDd',
                            );
                            debugPrint(
                              'Procesador guardado: $_selectedProcesador',
                            );
                            debugPrint(
                              'Sistema operativo guardado: $_selectedSistemaOperativo',
                            );
                            debugPrint(
                              'Versión S.O. guardada: $_selectedVersionSo',
                            );
                            debugPrint(
                              'Observaciones guardadas: ${_observacionesController.text}',
                            );
                            Navigator.pop(context, true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2E5C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Guardar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
