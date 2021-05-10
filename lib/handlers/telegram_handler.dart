import 'dart:collection';
import 'dart:convert';

import 'package:catcher/model/platform_type.dart';
import 'package:catcher/model/report.dart';
import 'package:catcher/model/report_handler.dart';
import 'package:catcher/utils/catcher_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class TelegramHandler extends ReportHandler {
  final Dio _dio = Dio();
  final Logger _logger = Logger("TelegramHandler");
  String? endpointUri;

  final String token;
  final String chatID;

  final bool printLogs;
  final Map<String, dynamic> headers;
  final int requestTimeout;
  final int responseTimeout;
  final bool enableDeviceParameters;
  final bool enableApplicationParameters;
  final bool enableStackTrace;
  final bool enableCustomParameters;
  final bool sendMessageWithScreenshot;

  TelegramHandler({
    required this.token,
    required this.chatID,
    this.printLogs = false,
    this.headers = const <String, dynamic>{},
    this.requestTimeout = 5000,
    this.responseTimeout = 5000,
    this.enableDeviceParameters = true,
    this.enableApplicationParameters = true,
    this.enableStackTrace = true,
    this.enableCustomParameters = false,
    this.sendMessageWithScreenshot = true,
  }) {
    this.endpointUri = "https://api.telegram.org/bot${this.token}";
  }

  @override
  Future<bool> handle(Report error, BuildContext? context) async {
    if (error.platformType != PlatformType.web) {
      if (!(await CatcherUtils.isInternetConnectionAvailable())) {
        _printLog("No internet connection available");
        return false;
      }
    }

    return _sendPost(error);
  }

  Future<bool> _sendPost(Report report) async {
    try {
      final jsonData = {
        "AppName": report.applicationParameters["appName"],
      };

      jsonData.addAll(report.toJson(
        enableDeviceParameters: enableDeviceParameters,
        enableApplicationParameters: enableApplicationParameters,
        enableStackTrace: enableStackTrace,
        enableCustomParameters: enableCustomParameters,
      ));
      final HashMap<String, dynamic> mutableHeaders =
          HashMap<String, dynamic>();
      if (headers.isNotEmpty == true) {
        mutableHeaders.addAll(headers);
      }

      final Options options = Options(
          sendTimeout: requestTimeout,
          receiveTimeout: responseTimeout,
          headers: mutableHeaders);

      JsonEncoder encoder = new JsonEncoder.withIndent('  ');
      String prettyMessage = encoder.convert(jsonData);
      Map<String, dynamic> datas = {
        "text": prettyMessage,
        "chat_id": this.chatID,
      };

      Response? response;
      String url = buildUrl(TelegramMethod.message);
      _printLog("Calling: ${url}");
      if (report.screenshot != null) {
        _printLog("ScreenShot is enabled");

        final screenshotPath = report.screenshot?.path ?? "";

        datas.addAll({
          "photo": await MultipartFile.fromFile(screenshotPath),
        });
        response = await _dio.post<dynamic>(
          endpointUri! + TelegramMethod.photo.urlPath,
          data: FormData.fromMap(datas),
          options: options,
        );
        if (sendMessageWithScreenshot) {
          datas.remove("photo");
          response = await _dio.post<dynamic>(
            endpointUri! + TelegramMethod.message.urlPath,
            data: datas,
            options: options,
          );
        }
      } else {
        _printLog("ScreenShot is NOT enabled");

        /* response = await _dio.post<dynamic>(
          url,
          data: json,
          options: options,
        ); */

        /* String query = endpointUri! +
            '/sendMessage?chat_id=${this.chatID}&text=' +
            json.encode(jsonData);
        print(query); */

        response = await _dio.post<dynamic>(
          endpointUri! + TelegramMethod.message.urlPath,
          data: datas,
          options: options,
        );
        _printLog(response.toString());
      }
      _printLog(
          "HttpHandler response status: ${response.statusCode!} body: ${response.data!}");
      return true;
    } catch (error, stackTrace) {
      _printLog("HttpHandler error: $error, stackTrace: $stackTrace");
      return false;
    }
  }

  void _printLog(String log) {
    if (printLogs) {
      _logger.info(log);
    }
  }

  @override
  String toString() {
    return 'HttpHandler';
  }

  @override
  List<PlatformType> getSupportedPlatforms() => [
        PlatformType.android,
        PlatformType.iOS,
        PlatformType.web,
        PlatformType.linux,
        PlatformType.macOS,
        PlatformType.windows,
      ];

  String buildUrl(TelegramMethod method) {
    return endpointUri! + method.urlPath;
  }
}

enum TelegramMethod { message, photo }

extension TelegramMethodX on TelegramMethod {
  String get urlPath {
    switch (this) {
      case TelegramMethod.message:
        return "/sendMessage";
      case TelegramMethod.photo:
        return "/sendPhoto";
      default:
        return "";
    }
  }
}
