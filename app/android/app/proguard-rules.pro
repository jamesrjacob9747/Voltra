# Razorpay Checkout (razorpay_flutter). Without these, R8 strips the classes the checkout
# finds by reflection, and payments fail only in release builds.
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
    public void onPayment*(...);
}
