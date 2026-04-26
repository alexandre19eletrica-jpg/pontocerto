{{flutter_js}}
{{flutter_build_config}}

(async function () {
  const buildVersion =
      document
          .querySelector('meta[name="pontocerto-build-version"]')
          ?.getAttribute('content') || 'unknown';
  const storedBuildVersion = window.localStorage.getItem(
    'pontocerto_build_version',
  );
  const versionMismatch =
      storedBuildVersion && storedBuildVersion !== buildVersion;

  if ('serviceWorker' in navigator) {
    try {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(registrations.map((registration) => registration.unregister()));
    } catch (error) {
      console.warn('Falha ao remover service workers antigos.', error);
    }
  }

  if ('caches' in window) {
    try {
      const cacheKeys = await caches.keys();
      await Promise.all(
        cacheKeys
            .filter((key) => key.includes('flutter') || key.includes('ponto'))
            .map((key) => caches.delete(key)),
      );
    } catch (error) {
      console.warn('Falha ao limpar cache antigo do navegador.', error);
    }
  }

  if (versionMismatch) {
    try {
      window.sessionStorage.removeItem('pontocerto_build_refresh_done');
    } catch (_) {}
  }

  try {
    window.localStorage.setItem('pontocerto_build_version', buildVersion);
  } catch (_) {}

  if (
    versionMismatch &&
    window.sessionStorage.getItem('pontocerto_build_refresh_done') != '1'
  ) {
    window.sessionStorage.setItem('pontocerto_build_refresh_done', '1');
    window.location.replace(window.location.href.split('#')[0]);
    return;
  }

  await _flutter.loader.load({
    serviceWorkerSettings: null,
  });
})();
