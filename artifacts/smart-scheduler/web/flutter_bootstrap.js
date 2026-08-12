{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' },
  onEntrypointLoaded: async function(engineInitializer) {
    let appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }
});
