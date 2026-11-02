# Room databases (WorkManager's WorkDatabase_Impl among them) are created via
# reflection from their generated no-arg constructor.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.ListenableWorker { <init>(...); }
-keep class * extends androidx.work.InputMerger { <init>(); }
