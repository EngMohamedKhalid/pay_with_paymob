// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:pay_with_paymob/pay_with_paymob.dart';
import 'package:pay_with_paymob/src/services/dio_helper.dart';
import 'package:pay_with_paymob/src/views/visa_view.dart';

import 'mobile_wallet_view.dart';

class PaymentView extends StatefulWidget {
  const PaymentView({
    super.key,
    required this.onPaymentSuccess,
    required this.onPaymentError,
    required this.price,
  });

  /// بدال VoidCallback بقى معاه Map
  final Function(Map<String, dynamic> data) onPaymentSuccess;
  final Function(Map<String, dynamic> error) onPaymentError;
  final double price;

  @override
  PaymentViewState createState() => PaymentViewState();
}

class PaymentViewState extends State<PaymentView> {
  String _selectedPaymentMethod = 'Visa';
  String redirectUrl = "";
  String paymentFirstToken = '';
  String paymentOrderId = '';
  String finalToken = '';
  final PaymentData paymentData = PaymentData();

  bool isAuthLoading = false,
      isOrderLoading = false,
      isPaymentRequestLoading = false,
      isMobileWalletLoading = false;

  final TextEditingController walletMobileNumber = TextEditingController();

  @override
  void initState() {
    super.initState();
    getAuthToken();
  }

  bool isLoading() =>
      isAuthLoading || isOrderLoading || isPaymentRequestLoading || isMobileWalletLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paymentData.style?.scaffoldColor,
      appBar: _buildAppBar(),
      body: isLoading()
          ? Center(
              child: CircularProgressIndicator(
                color: paymentData.style?.circleProgressColor ?? Colors.blue,
              ),
            )
          : _buildPaymentOptions(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: paymentData.style?.appBarBackgroundColor,
      foregroundColor: paymentData.style?.appBarForegroundColor,
      title: const Text('Select Payment Method'),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new_outlined),
      ),
    );
  }

  Widget _buildPaymentOptions() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildPaymentOption(
            label: 'Pay with Visa',
            icon: Icons.credit_card,
            isSelected: _selectedPaymentMethod == 'Visa',
            onTap: () => _setSelectedPaymentMethod('Visa'),
          ),
          const SizedBox(height: 20),
          _buildPaymentOption(
            label: 'Pay with Mobile Wallet',
            icon: Icons.phone_android,
            isSelected: _selectedPaymentMethod == 'Mobile Wallet',
            onTap: () => _setSelectedPaymentMethod('Mobile Wallet'),
            isVisa: false,
          ),
          const SizedBox(height: 30),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _selectedPaymentMethod == 'Visa'
                ? Container()
                : _buildMobileWalletForm(),
          ),
          const Spacer(),
          _buildConfirmPaymentButton(),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isVisa = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? paymentData.style?.primaryColor ?? Colors.blue
                : paymentData.style?.unselectedColor ?? Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? paymentData.style?.primaryColor ?? Colors.blue
                    : paymentData.style?.unselectedColor ?? Colors.grey),
            const SizedBox(width: 10),
            Text(label, style: paymentData.style?.textStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileWalletForm() {
    return Column(
      children: [
        TextFormField(
          controller: walletMobileNumber,
          keyboardType: TextInputType.number,
          cursorColor: paymentData.style?.primaryColor ?? Colors.blue,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.wallet,
                color: paymentData.style?.primaryColor ?? Colors.blue),
            hintText: 'Enter your mobile wallet number',
            hintStyle: paymentData.style?.textStyle,
            border: _inputBorder(),
            focusedBorder: _inputBorder(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  OutlineInputBorder _inputBorder() {
    return OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      borderSide:
          BorderSide(color: paymentData.style?.primaryColor ?? Colors.blue, width: 2),
    );
  }

  Widget _buildConfirmPaymentButton() {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          await _handlePaymentConfirmation();
        },
        style: paymentData.style?.buttonStyle ?? _defaultButtonStyle(),
        child: const Text('Confirm Payment', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  ButtonStyle _defaultButtonStyle() {
    return ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    );
  }

  void _setSelectedPaymentMethod(String method) {
    setState(() {
      _selectedPaymentMethod = method;
    });
  }

  Future<void> _handlePaymentConfirmation() async {
    try {
      await getOrderRegisrationId();
      if (_selectedPaymentMethod == 'Visa') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisaScreen(
              onError: () => widget.onPaymentError({
                "status": "error",
                "message": "Visa payment failed",
                "orderId": paymentOrderId,
                "finalToken": finalToken,
                "redirectUrl": redirectUrl,
                "iframeId":  paymentData.iframeId,
              }),
              onFinished: () => widget.onPaymentSuccess({
                "status": "success",
                "method": "Visa",
                "orderId": paymentOrderId,
                "finalToken": finalToken,
                "redirectUrl": redirectUrl,
                "iframeId":  paymentData.iframeId,
              }),
              finalToken: finalToken,
              iframeId: paymentData.iframeId,
            ),
          ),
        );
      } else {
        await payWithMobileWallet(walletMobileNumber: walletMobileNumber.text);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MobileWalletScreen(
              onError: () => widget.onPaymentError({
                "status": "error",
                "message": "Mobile Wallet payment failed",
                "orderId": paymentOrderId,
                "finalToken": finalToken,
                "redirectUrl": redirectUrl,
              }),
              onSuccess: () => widget.onPaymentSuccess({
                "status": "success",
                "method": "Mobile Wallet",
                "orderId": paymentOrderId,
                "redirectUrl": redirectUrl,
                "finalToken": finalToken,
              }),
              redirectUrl: redirectUrl,
            ),
          ),
        );
      }
    } catch (e) {
      widget.onPaymentError({
        "status": "error",
        "message": e.toString(),
      });
    }
  }

  Future<void> getAuthToken() async {
    try {
      final response = await DioHelper.postData(
        url: '/auth/tokens',
        data: {
          "api_key": paymentData.apiKey,
        },
      );
      paymentFirstToken = response.data['token'];
    } catch (error) {
      widget.onPaymentError({
        "status": "error",
        "message": error.toString(),
      });
    }
  }

  Future<void> getOrderRegisrationId() async {
    try {
      final response = await DioHelper.postData(
        url: '/ecommerce/orders',
        data: {
          "auth_token": paymentFirstToken,
          "delivery_needed": "false",
          "amount_cents": (widget.price * 100).toString(),
          "currency": "EGP",
          "items": [],
        },
      );
      paymentOrderId = response.data['id'].toString();
      await getPaymentRequest();
    } catch (error) {
      widget.onPaymentError({
        "status": "error",
        "message": error.toString(),
      });
    }
  }

  Future<void> getPaymentRequest() async {
    final requestData = {
      "auth_token": paymentFirstToken,
      "amount_cents": (widget.price * 100).toString(),
      "expiration": 3600,
      "order_id": paymentOrderId,
      "billing_data": {
        "apartment": "NA",
        "email": paymentData.userData?.email ?? 'NA',
        "floor": "NA",
        "first_name": paymentData.userData?.name ?? 'NA',
        "street": "NA",
        "building": "NA",
        "phone_number": paymentData.userData?.phone ?? 'NA',
        "shipping_method": "NA",
        "postal_code": "NA",
        "city": "NA",
        "country": "NA",
        "last_name": paymentData.userData?.lastName ?? 'NA',
        "state": "NA",
      },
      "currency": "EGP",
      "integration_id": _selectedPaymentMethod == 'Visa'
          ? paymentData.integrationCardId
          : paymentData.integrationMobileWalletId,
      "lock_order_when_paid": "false",
    };

    try {
      final response = await DioHelper.postData(
        url: '/acceptance/payment_keys',
        data: requestData,
      );
      print("getPaymentRequest $response");
      finalToken = response.data['token'];
    } catch (error) {
      widget.onPaymentError({
        "status": "error",
        "message": error.toString(),
      });
    }
  }

  Future<void> payWithMobileWallet({required String walletMobileNumber}) async {
    final paymentData = {
      "source": {
        "identifier": walletMobileNumber,
        "subtype": "WALLET",
      },
      "payment_token": finalToken,
    };

    try {
      final response = await DioHelper.postData(
        url: '/acceptance/payments/pay',
        data: paymentData,
      );

      if (response.data.containsKey('redirect_url')) {
        redirectUrl = response.data['redirect_url'].toString();
      } else {
        widget.onPaymentError({
          "status": "error",
          "message": "No redirect_url found",
        });
      }
    } catch (error) {
      widget.onPaymentError({
        "status": "error",
        "message": error.toString(),
      });
    }
  }

  @override
  void dispose() {
    walletMobileNumber.dispose();
    super.dispose();
  }
}
