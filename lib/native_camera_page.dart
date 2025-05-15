import 'package:flutter/material.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  Widget _circleButton(IconData icon, VoidCallback onTap, {double size=50}){
    return ClipOval(
      child: Material(
        color: Colors.white24,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls(){
    if(!_isZoomSupported) return const SizedBox.shrink();

    return Positioned(
      bottom: 160,
      left: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _circleButton(Icons.looks_one, () => _setZoom(1.0), size: 44),
              const SizedBox(width: 10,),
              if(_maxzoom >= 3.0)
                _circleButton(Icons.looks_3, ()=> _setZoom(3.0), size: 44),
              const SizedBox(width: 10),
              if(_maxzoom >= 5.0)
                _circleButton(Icons.looks_5, ()=> _setZoom(5.0),size: 44),
            ],
          ),
          const SizedBox(height: 12,),
          Row(
            children: [
              const Icon(Icons.zoom_out, color: Colors.white,),
              Expanded(
                child: Slider(
                  value: _zoom,
                  min: _minzoom,
                  max: _maxzoom,
                  divisions: ((_maxzoom-_minzoom)*10).toInt(), 
                  label: '${_zoom.toStringAsFixed(1)}%',
                  onChanged: (value)=>_setZoom(value),
                  )
                ),
              const Icon(Icons.zoom_in, color: Colors.white,),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${_zoom.toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white),),
          )
        ],
      )
    );
  }
  @override
  void dispose(){
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
  late List<CameraDescription> _cameras;
  CameraController? _controller;
  int _selectedCameraIdX = 0;
  FlashMode _flashMode = FlashMode.off;
  double _zoom = 1.0;
  double _minzoom = 1.0;
  double _maxzoom = 1.0;
  bool _isZoomSupported = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    await _setupCamera(_selectedCameraIdX);
  }

  Future<void> _setupCamera(int cameraIndex) async {
    if(_controller != null){
      await _controller!.dispose();
    }

    final controller = CameraController(
      _cameras[cameraIndex], 
      ResolutionPreset.max,
      enableAudio: false
    );

    await controller.initialize();
    _minzoom = await controller.getMinZoomLevel();
    _maxzoom = await controller.getMaxZoomLevel();
    _isZoomSupported = _maxzoom > _minzoom;
    _zoom = _minzoom;
    await controller.setZoomLevel(_zoom);
    await controller.setFlashMode(_flashMode);

    if(mounted){
      setState(() {
        _controller = controller;
        _selectedCameraIdX = cameraIndex;
      });
    }
  }

  Future<void> _captureImage() async{
    final XFile file = await _controller!.takePicture();
    Navigator.pop(context, File(file.path));
  }

  void _switchCamera() async{
    final nextIndex = (_selectedCameraIdX +1 ) % _cameras.length;
    await _setupCamera(nextIndex);
  }

  void _toggleFlash() async{
    FlashMode next = _flashMode == FlashMode.off
      ? FlashMode.auto
      : _flashMode == FlashMode.auto
          ? FlashMode.always
          : FlashMode.off;
    await _controller!.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  void _setZoom(double value) async{
    if(!_isZoomSupported) return;
    _zoom = value.clamp(_minzoom, _maxzoom);
    await _controller!.setZoomLevel(_zoom);
    setState(() {});
  }

  void _handleTap(TapDownDetails details, BoxConstraints constraints){
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth, 
      details.localPosition.dy / constraints.maxHeight);

      _controller?.setFocusPoint(offset);
      _controller?.setExposurePoint(offset);
  }

  IconData _flashIcon(){
    switch(_flashMode){
      case FlashMode.auto:
      return Icons.flash_auto;
      case FlashMode.always:
      return Icons.flash_on;
      default:
      return Icons.flash_off;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: (_controller?.value.isInitialized ?? false)
        ? LayoutBuilder(
          builder: (context, constraints){
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTapDown: (d) => _handleTap(d, constraints),
                  child: CameraPreview(_controller!),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: Column(
                    children: [
                      _circleButton(
                        Icons.flip_camera_android, _switchCamera),
                      const SizedBox(height: 12,),
                      _circleButton(_flashIcon(), _toggleFlash),
                    ],
                  )
                ),
                _buildZoomControls(),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(onPressed: _captureImage,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.camera_alt, color: Colors.black),
                  ),
                )
              )
              ],
            );
          }
        )
      : const Center(child: CircularProgressIndicator()),
    );
  }
}