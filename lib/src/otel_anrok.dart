// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_anrok_suppression.dart';

const _tracerName = 'dartastic_otel_libs_anrok';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class AnrokResult {
  const AnrokResult({
    this.transactionId,
    this.transactionKind,
    this.canonical,
    this.lineCount,
    this.totalTaxMinor,
    this.currency,
    this.country,
    this.jurisdiction,
    this.taxBehavior,
    this.productExempt,
    this.requestId,
    this.statusCode,
  });

  /// `transactionId`.
  final String? transactionId;

  /// `quote` / `invoice` / `credit_memo`. Anrok distinguishes quotes
  /// (ephemeral) from canonical-of-record postings.
  final String? transactionKind;

  /// True when this is a canonical transaction (counts toward filing,
  /// retained for compliance).
  final bool? canonical;

  /// Lines on the transaction.
  final int? lineCount;

  /// Total tax in minor units.
  final int? totalTaxMinor;

  /// ISO 4217.
  final String? currency;

  /// ISO 3166 country.
  final String? country;

  /// US state code or VAT jurisdiction.
  final String? jurisdiction;

  /// `inclusive` / `exclusive` — drives final price math.
  final String? taxBehavior;

  /// Whether the product was treated as exempt (e.g. SaaS in non-
  /// taxable states).
  final bool? productExempt;

  /// `X-Anrok-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class AnrokCallResult<T> {
  const AnrokCallResult({required this.value, this.result});
  final T value;
  final AnrokResult? result;
}

/// Wraps an Anrok API call in a CLIENT span. [operation] is one of
/// `quote.create`, `invoice.create`, `invoice.update`,
/// `invoice.void`, `credit_memo.create`, `customer.address.validate`,
/// `registration.list`, `filing.list`, `filing.get`, `nexus.evaluate`,
/// `webhook.list`.
Future<T> tracedAnrok<T>({
  required String operation,
  required Future<AnrokCallResult<T>> Function() invoke,
}) async {
  if (anrokInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'anrok',
    'rpc.method': operation,
    'anrok.operation': operation,
  };

  final span = _tracer().startSpan(
    'anrok $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.transactionId != null) {
        extras.add(OTel.attributeString(
          'anrok.transaction.id',
          r.result!.transactionId!,
        ));
      }
      if (r.result!.transactionKind != null) {
        extras.add(OTel.attributeString(
          'anrok.transaction.kind',
          r.result!.transactionKind!,
        ));
      }
      if (r.result!.canonical != null) {
        extras.add(OTel.attributeBool(
          'anrok.transaction.canonical',
          r.result!.canonical!,
        ));
      }
      if (r.result!.lineCount != null) {
        extras.add(OTel.attributeInt(
          'anrok.line_count',
          r.result!.lineCount!,
        ));
      }
      if (r.result!.totalTaxMinor != null) {
        extras.add(OTel.attributeInt(
          'anrok.tax.total.minor',
          r.result!.totalTaxMinor!,
        ));
      }
      if (r.result!.currency != null) {
        extras.add(OTel.attributeString(
          'anrok.currency',
          r.result!.currency!,
        ));
      }
      if (r.result!.country != null) {
        extras.add(OTel.attributeString(
          'anrok.country',
          r.result!.country!,
        ));
      }
      if (r.result!.jurisdiction != null) {
        extras.add(OTel.attributeString(
          'anrok.jurisdiction',
          r.result!.jurisdiction!,
        ));
      }
      if (r.result!.taxBehavior != null) {
        extras.add(OTel.attributeString(
          'anrok.tax_behavior',
          r.result!.taxBehavior!,
        ));
      }
      if (r.result!.productExempt != null) {
        extras.add(OTel.attributeBool(
          'anrok.product_exempt',
          r.result!.productExempt!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'anrok.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Anrok HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
