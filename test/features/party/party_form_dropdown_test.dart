import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:projectbtt/features/auth/domain/models/user_model.dart';
import 'package:projectbtt/features/auth/presentation/providers/auth_provider.dart';
import 'package:projectbtt/features/party/presentation/screens/party_form_screen.dart';

class MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  MockAuthNotifier(AuthState state) : super(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final ownerUser = UserModel(
    uid: 'owner_1',
    email: 'owner@test.com',
    name: 'Owner User',
    role: 'Owner',
    companyId: 'comp_1',
  );

  Widget createTestWidget({Map<String, dynamic>? initialValues}) {
    final authState = AuthState(
      isLoggedIn: true,
      isInitialized: true,
      user: ownerUser,
    );

    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => MockAuthNotifier(authState)),
      ],
      child: MaterialApp(
        home: PartyFormScreen(
          initialValues: initialValues,
        ),
      ),
    );
  }

  group('PartyFormScreen Dropdown Assertion Regression Tests', () {
    testWidgets('Opening form with invalid state "Pune" does not crash and leaves state as null', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialValues: {
            'partyName': 'ABC Industries',
            'address': 'Hadapsar, Pune',
            'state': 'Pune', // City passed as state by AI or user
          },
        ),
      );
      await tester.pump();

      // Verify no DropdownButton assertion was thrown
      expect(tester.takeException(), isNull);

      // Verify partyName and address were populated
      expect(find.text('ABC Industries'), findsOneWidget);
      expect(find.text('Hadapsar, Pune'), findsOneWidget);

      // Verify dropdown shows hint "Select State" since "Pune" is not in kIndianStateCodes
      expect(find.text('Select State'), findsOneWidget);
    });

    testWidgets('Opening form with partyType "Vendor" normalizes to "Supplier" without crashing', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialValues: {
            'partyName': 'XYZ Metals',
            'partyType': 'Vendor',
          },
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Supplier'), findsOneWidget);
    });

    testWidgets('Opening form with valid state "Maharashtra" selects state and auto-fills state code', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialValues: {
            'partyName': 'Supreme Precision',
            'state': 'Maharashtra',
            'partyType': 'Customer',
          },
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Maharashtra'), findsOneWidget);
      expect(find.text('27'), findsOneWidget); // State code for Maharashtra
    });

    testWidgets('Opening form with case-insensitive state "karnataka" normalizes to "Karnataka"', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialValues: {
            'partyName': 'Bangalore Tools',
            'state': 'karnataka',
          },
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Karnataka'), findsOneWidget);
      expect(find.text('29'), findsOneWidget); // State code for Karnataka
    });
    testWidgets('Opening form with contact person name correctly populates contactPersonName', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialValues: {
            'partyName': 'Apex Steels',
            'contactPersonName': 'Rahul Sharma',
            'contactNumber': '9876543210',
          },
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
    });

    testWidgets('Opening form ignores copied phone number in vendorCode', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialValues: {
            'partyName': 'Apex Steels',
            'contactNumber': '9876543210',
            'vendorCode': '9876543210', // Phone mistakenly copied as vendorCode
          },
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Verify vendorCode is empty and not pre-filled with phone number
      final textFormField = find.widgetWithText(TextFormField, 'e.g. VEN-001');
      expect(textFormField, findsOneWidget);
      final widget = tester.widget<TextFormField>(textFormField);
      expect(widget.controller?.text, isEmpty);
    });
  });
}

