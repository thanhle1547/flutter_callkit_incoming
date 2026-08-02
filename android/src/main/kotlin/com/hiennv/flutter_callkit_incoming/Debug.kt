package com.hiennv.flutter_callkit_incoming

import android.util.Log

object Debug {
    var sendDebugLog: (tag: String, msg: String) -> Unit = { tag, msg -> Log.d(tag, msg) }
    var sendVerboseLog: (tag: String, msg: String) -> Unit = { tag, msg -> Log.v(tag, msg) }
    var sendWarnLog: (tag: String, msg: String) -> Unit = { tag, msg -> Log.w(tag, msg) }
    var sendErrorLog: (tag: String, msg: String) -> Unit = { tag, msg -> Log.e(tag, msg) }
    var sendErrorException: (tag: String, tr: Throwable) -> Unit = { tag, tr -> Log.e(tag, null, tr) }
}