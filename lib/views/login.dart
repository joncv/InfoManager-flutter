import "dart:async";
import "package:flutter/material.dart";
import "package:redux/redux.dart";
import "package:flutter_redux/flutter_redux.dart";
import "package:fluttertoast/fluttertoast.dart";
import "package:local_auth/local_auth.dart";
import "package:local_auth/auth_strings.dart";
import "package:firebase_admob/firebase_admob.dart";

import "../configure/app_configure.dart";

import "package:info_manager/store/app_state.dart";
import "package:info_manager/store/app_actions.dart";

import "package:info_manager/mixins/i18n_mixin.dart";
import "package:info_manager/service/user_service.dart";
import "package:info_manager/service/app_service.dart";
import "package:info_manager/service/shared_preference_service.dart";

typedef void SetPasswordActionType(String password);

class LoginView extends StatefulWidget {
    @override
    _LoginViewState createState() => new _LoginViewState();
}

class _LoginViewState extends State<LoginView> with I18nMixin {
    String currentPassword;
    GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
    int inputErrorCount = 0;
    bool isEnableFingerPrintUnlock = false;
    bool isEnableDeleteFile = false;
    BannerAd bannerAd;
    bool isEnableAd = false;

    static final MobileAdTargetingInfo targetingInfo = new MobileAdTargetingInfo(
        testDevices: <String>[APP_CONFIGURE["AD_DEVICE_ID"]]
    );

    BannerAd createBannerAd() {
        return new BannerAd(
            adUnitId: APP_CONFIGURE["AD_MOB_AD_ID"],
            targetingInfo: targetingInfo,
            size: AdSize.smartBanner,
            listener: (MobileAdEvent event) {
                print(event.toString());
            }
        );
    }

    @override
    void initState() {
        super.initState();

        SharedPreferenceService.getIsEnableDeleteFile().then((isEnableDeleteFile) {
            SharedPreferenceService.getIsEnableFingerPrintUnlock().then((isEnableFingerPrintUnlock) {
                setState(() {
                    this.isEnableDeleteFile = isEnableDeleteFile;
                    this.isEnableFingerPrintUnlock = isEnableFingerPrintUnlock;
                });
            });
        });

        if (this.isEnableAd) {
            FirebaseAdMob.instance.initialize(appId: APP_CONFIGURE["AD_MOB_APP_ID"]);
            bannerAd = createBannerAd()..load()..show(
                anchorType: AnchorType.bottom,
                anchorOffset: 0.0
            );
        }
    }

    @override
    Widget build(BuildContext context) {
        return new Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: 150.0, right: 10.0, left: 10.0),
            height: 300.0,
            child: new Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                    this._buildLoginPanel(context)
                ],
            )
        );
    }

    @override
    void dispose() {
        bannerAd?.dispose();
        super.dispose();
    }

    Widget _buildLoginPanel(BuildContext context) {
        return new Card(
            child: new Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                    this._buildHeader(context),
                    this._buildBody(context)
                ],
            ),
        );
    }

    Widget _buildHeader(BuildContext context) {
        return new Container(
            color: Colors.blue,
            padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
            child: new Text(
                this.getI18nValue(context, "please_login"),
                textAlign: TextAlign.left,
                style: new TextStyle(
                    color: Colors.white,
                    fontSize: 18.0
                ),
            ),
        );
    }

    Widget _buildBody(BuildContext context) {
        return new Container(
            padding: EdgeInsets.fromLTRB(16.0, 20.0, 15.0, 40.0),
            child: new Form(
                key: _formKey,
                child: new Column(
                    children: <Widget>[
                        TextFormField(
                            obscureText: true,
                            decoration: new InputDecoration(

                                labelText: this.getI18nValue(context, "password"),
                                hintText: this.getI18nValue(context, "please_input_password"),
                            ),
                            validator: (value) {
                                if (value.isEmpty) {
                                    return this.getI18nValue(context, "please_input_password");
                                }
                            },

                            onSaved: (value) {
                                this.currentPassword = value;
                            },

                        ),
                        new Container(
                            margin: EdgeInsets.only(top: 50.0),
                            child: new StoreConnector<AppState, SetPasswordActionType>(
                                converter: (store) {
                                    return (String password) {
                                        SetPasswordAction action = new SetPasswordAction(password);

                                        store.dispatch(action);
                                    };
                                },
                                builder: (context, updatePasswordAction) {
                                    List<Widget> widgets = [];

                                    widgets.add(
                                        new RaisedButton(
                                            color: Colors.blue,
                                            onPressed: () => this._handleLogin(context, updatePasswordAction),
                                            child: new Text(
                                                this.getI18nValue(context, "login"),
                                                style: new TextStyle(
                                                    color: Colors.white
                                                )
                                            ),
                                        )
                                    );

                                    if (this.isEnableFingerPrintUnlock) {
                                        widgets.add(
                                            new RaisedButton(
                                                color: Colors.teal,
                                                onPressed: () => this.handleFingerLogin(context, updatePasswordAction),
                                                child: new Text(
                                                    this.getI18nValue(context, "fingerprint"),
                                                    style: new TextStyle(
                                                        color: Colors.white
                                                    )
                                                ),
                                            )
                                        );
                                    }

                                    return new Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: widgets,
                                    );
                                },
                            ),
                        ),
                    ],
                ),
            ),
        );
    }


    void _handleLogin(BuildContext context, SetPasswordActionType updatePasswordAction) async {
        if (this._formKey.currentState.validate()) {
            this._formKey.currentState.save();

            bool loginSuccess = await UserService.login(this.currentPassword);

            if (loginSuccess) {
                this.handleLoginSuccess(context, this.currentPassword, updatePasswordAction);
            } else {
                await this.handlePasswordError();
            }
        }
    }

    void handleFingerLogin(BuildContext context, SetPasswordActionType updatePasswordAction) async {
        var localAuth = new LocalAuthentication();
        dynamic androidStrings = AndroidAuthMessages(
            cancelButton: this.getI18nValue(context, "cancel"),
            goToSettingsButton: this.getI18nValue(context, "setting"),
            goToSettingsDescription: this.getI18nValue(context, "setting_fingureprint_desc"),
            fingerprintNotRecognized: this.getI18nValue(context, "fingerprint_not_recongnized"),
            signInTitle: this.getI18nValue(context, "auth_fingerprint"),
            fingerprintSuccess: this.getI18nValue(context, "fingerprint_auth_success")
        );

        bool didAuthenticate = await localAuth.authenticateWithBiometrics(
            localizedReason: this.getI18nValue(context, "please_auth_fingerprint"),
            androidAuthStrings: androidStrings,
            useErrorDialogs: false
        );

        if (didAuthenticate) {
            String password = await SharedPreferenceService.getUserPassword();
            this.handleLoginSuccess(context, password, updatePasswordAction);
        } else {
            await this.handlePasswordError();
        }

    }

    Future<Null> handlePasswordError() async {
        if (this.isEnableDeleteFile) {
            this.inputErrorCount++;
        }

        if (this.inputErrorCount == this.getErrorPasswordMaxCount(context)) {
            Fluttertoast.showToast(
                msg: this.getI18nValue(context, "input_password_error_more_than_max_count")
            );
            await AppService.deleteFile();
        } else {
            Fluttertoast.showToast(
                msg: this.getI18nValue(context, "password_is_error")
            );
        }

        return null;
    }

    void handleLoginSuccess(BuildContext context, String password, SetPasswordActionType updatePasswordAction) async {
        updatePasswordAction(password);


        Store<AppState> store = StoreProvider.of<AppState>(context);
        await AppService.loadAppStateData(store);


        new Future.delayed(new Duration(milliseconds: 100), () {
            store.dispatch(new SetListenStoreStatusAction(true));
        });
        Navigator.pushReplacementNamed(context, "infoListView");
    }

    int getErrorPasswordMaxCount(BuildContext context) {
        Store<AppState> store = this.getStore(context);

        return store.state.userInfo.maxErrorCount;
    }

    Store<AppState> getStore(BuildContext context) {
        return StoreProvider.of<AppState>(context);
    }
}