import 'package:sentry/sentry.dart' show SentryHttpClient;

var client = SentryHttpClient(
    captureFailedRequests: true,
    networkTracing: true,
    recordBreadcrumbs: true,
    sendDefaultPii: true);
