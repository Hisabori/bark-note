package com.barknote.bark_note

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingArgs: Map<*, *>? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.railtime/alerts").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(getSharedPreferences("departure",Context.MODE_PRIVATE).getLong("epoch",0))
                "cancel" -> { Reminder.cancel(this); result.success(true) }
                "schedule" -> {
                    val args=call.arguments as? Map<*, *>
                    val epoch=(args?.get("epoch") as? Number)?.toLong()
                    if (epoch==null || epoch<=System.currentTimeMillis()) { result.error("TIME","출발 시각이 지났습니다.",null) }
                    else if (pendingResult!=null) { result.error("BUSY","알림 권한을 확인하고 있습니다.",null) }
                    else if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) {
                        pendingResult=result; pendingArgs=args
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),4107)
                    } else { schedule(args,result) }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun schedule(args: Map<*, *>?, result: MethodChannel.Result) {
        try {
            val nm=getSystemService(NotificationManager::class.java)
            if(!nm.areNotificationsEnabled()){result.success(false);return}
            val epoch=(args?.get("epoch") as? Number)?.toLong() ?: 0L
            Reminder.schedule(this,epoch,args?.get("title") as? String ?: "나갈 시간",args?.get("body") as? String ?: "출발 계획을 확인해주세요.")
            result.success(true)
        }catch(e: Exception){result.error("ALARM","알림 예약 실패",null)}
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode,permissions,grantResults)
        if(requestCode==4107){val result=pendingResult;val args=pendingArgs;pendingResult=null;pendingArgs=null
            if(result!=null){if(grantResults.isNotEmpty() && grantResults[0]==PackageManager.PERMISSION_GRANTED){schedule(args,result)}else{result.success(false)}}
        }
    }
}
object Reminder {
    private fun intent(context: Context)=PendingIntent.getBroadcast(context,4107,Intent(context,DepartureReceiver::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun schedule(context: Context,epoch: Long,title: String,body: String){
        require(epoch>System.currentTimeMillis())
        val prefs=context.getSharedPreferences("departure",Context.MODE_PRIVATE)
        prefs.edit().putLong("epoch",epoch).putString("title",title).putString("body",body).apply()
        context.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,epoch,intent(context))
    }
    fun cancel(context: Context){context.getSystemService(AlarmManager::class.java).cancel(intent(context));context.getSystemService(NotificationManager::class.java).cancel(4107);context.getSharedPreferences("departure",Context.MODE_PRIVATE).edit().clear().apply()}
}
class DepartureReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent){
        val prefs=context.getSharedPreferences("departure",Context.MODE_PRIVATE)
        val epoch=prefs.getLong("epoch",0)
        val title=prefs.getString("title","나갈 시간") ?: "나갈 시간"
        val body=prefs.getString("body","출발 계획을 확인해주세요.") ?: "출발 계획을 확인해주세요."
        if(intent.action==Intent.ACTION_BOOT_COMPLETED){if(epoch>System.currentTimeMillis()){Reminder.schedule(context,epoch,title,body)};return}
        if(epoch==0L)return
        val nm=context.getSystemService(NotificationManager::class.java)
        if(Build.VERSION.SDK_INT>=26){nm.createNotificationChannel(NotificationChannel("departures","출발 알림",NotificationManager.IMPORTANCE_HIGH))}
        val open=PendingIntent.getActivity(context,4107,Intent(context,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder=if(Build.VERSION.SDK_INT>=26) android.app.Notification.Builder(context,"departures") else android.app.Notification.Builder(context)
        try{nm.notify(4107,builder.setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle(title).setContentText(body).setContentIntent(open).setAutoCancel(true).build())}catch(_: SecurityException){}
        prefs.edit().clear().apply()
    }
}
