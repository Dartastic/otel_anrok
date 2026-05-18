// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_anrok/otel_anrok.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_anrok-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('invoice.create records canonical + jurisdiction + behavior', () async {
    await tracedAnrok<String>(
      operation: 'invoice.create',
      invoke: () async => const AnrokCallResult(
        value: 'ok',
        result: AnrokResult(
          transactionId: 'tx-1',
          transactionKind: 'invoice',
          canonical: true,
          lineCount: 3,
          totalTaxMinor: 875,
          currency: 'USD',
          country: 'US',
          jurisdiction: 'NY',
          taxBehavior: 'exclusive',
          productExempt: false,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('anrok invoice.create')!);
    expect(a['anrok.transaction.canonical'], true);
    expect(a['anrok.transaction.kind'], 'invoice');
    expect(a['anrok.jurisdiction'], 'NY');
    expect(a['anrok.tax_behavior'], 'exclusive');
  });

  test('quote treated as ephemeral', () async {
    await tracedAnrok<String>(
      operation: 'quote.create',
      invoke: () async => const AnrokCallResult(
        value: 'ok',
        result: AnrokResult(
          transactionKind: 'quote',
          canonical: false,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('anrok quote.create')!);
    expect(a['anrok.transaction.canonical'], false);
  });

  test('suppression skips spans', () async {
    await runWithoutAnrokInstrumentationAsync(() async {
      await tracedAnrok<String>(
        operation: 'nexus.evaluate',
        invoke: () async => const AnrokCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('anrok '), isEmpty);
  });
}
