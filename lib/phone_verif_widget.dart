import 'package:auth_helper/authservice.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:ui_kosmos_v4/cta/theme.dart';
import 'package:ui_kosmos_v4/ui_kosmos_v4.dart';

class PhoneVerification extends StatefulWidget {
  final PhoneNumber phoneNumber;
  final CtaThemeData? ctaThemeData;
  final PinTheme? pinTheme;
  final Color? cursorColor;
  final Function(PhoneAuthCredential? phoneAuthCredential) verifSucces;
  const PhoneVerification(
      {required this.phoneNumber, required this.verifSucces, this.ctaThemeData, this.pinTheme, this.cursorColor, Key? key})
      : super(key: key);

  @override
  State<PhoneVerification> createState() => _PhoneVerificationState();
}

class _PhoneVerificationState extends State<PhoneVerification> {
  String? verificationId_;
  bool loadingSendingCode = false;
  Duration? seconds;
  FToast fToast = FToast();
  String? codeVerification_;

  @override
  void initState() {
    fToast.init(context);
    loadingSendingCode = true;
    AuthService.verifPhoneNumberAndGetCredential(
      context: context,
      phone: widget.phoneNumber.phoneNumber!,
      connexionDone: () => widget.verifSucces(null),
      codeSent: (verificationId, resendToken) {
        setState(() {
          verificationId_ = verificationId;
          loadingSendingCode = false;
          seconds = const Duration(minutes: 1);
        });
      },
      redirectAfterTimeOut: () {},
      setLoading: () {},
      fToast: fToast,
    );
    super.initState();
  }

  final codeVerificationForm = GlobalKey<FormState>(debugLabel: 'codeVerificationForm');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loadingSendingCode
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF02132B),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 53),
                    Row(
                      children: [
                        CTA.back(
                          onTap: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 35.5),
                    const Text(
                      "Validez votre numéro de téléphone",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Visibility(
                      replacement: Center(
                          child: InkWell(
                              child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Le code a expiré.',
                            style: TextStyle(
                              color: Color(0XFFC2C2C2),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          InkWell(
                            onTap: null,
                            child: Text(
                              'Renvoyer un nouveau code',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ))),
                      // visible: seconds > 0,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 31.0),
                          child: Container(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 35.5),
                    const Text('Code reçu par SMS',
                        style: TextStyle(color: Color(0XFFDBDBDB), fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Form(
                      key: codeVerificationForm,
                      child: PinCodeTextField(
                        appContext: context,
                        textStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 20),
                        pastedTextStyle: TextStyle(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                        length: 6,
                        blinkWhenObscuring: true,
                        animationType: AnimationType.fade,
                        validator: (v) {
                          if ((v?.length ?? 0) < 6) {
                            return "Le code n’est pas complet";
                          } else {
                            return null;
                          }
                        },
                        pinTheme: widget.pinTheme ??
                            PinTheme(
                              errorBorderColor: Colors.red,
                              inactiveFillColor: const Color(0XFFF6F6F6),
                              inactiveColor: const Color(0XFFF6F6F6),
                              activeColor: const Color(0XFFF6F6F6),
                              selectedFillColor: const Color(0XFFF6F6F6),
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(7),
                              fieldHeight: 54,
                              fieldWidth: 50,
                              activeFillColor: Colors.white,
                            ),
                        cursorColor: widget.cursorColor ?? const Color(0xFF02132B),
                        animationDuration: const Duration(milliseconds: 300),
                        enableActiveFill: true,
                        keyboardType: TextInputType.number,
                        onCompleted: (codeVerification) {
                          setState(() {
                            codeVerification_ = codeVerification;
                          });
                          widget.verifSucces(PhoneAuthProvider.credential(
                              verificationId: verificationId_!, smsCode: codeVerification));
                        },
                        beforeTextPaste: (text) {
                          print("Allowing to paste $text");
                          return true;
                        }, onChanged: (String value) {},
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 38),
                    Center(
                      child: CTA.primary(
                          theme: widget.ctaThemeData,
                          textButton: "Valider et continuer",
                          width: 317,
                          onTap: () async {
                            if (codeVerificationForm.currentState!.validate()) {
                              widget.verifSucces(PhoneAuthProvider.credential(
                                  verificationId: verificationId_!, smsCode: codeVerification_!));
                              // register(verificationId: this.verificationId!, codeVerification: codeMessage);
                            } else {}
                          }),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
    );
  }
}
