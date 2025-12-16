plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.5.0"))

    // TODO: Add the dependencies for Firebase products you want to use
    // When using the BoM, don't specify versions in Firebase dependencies
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")

    // Add the dependencies for any other desired Firebase products
    // https://firebase.google.com/docs/android/setup#available-libraries
}

android {
    namespace = "com.chaski.comercial"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.chaski.comercial"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // HE COMENTADO ESTO PARA QUE NO TE PIDA LA LLAVE QUE FALTA
    /*
    signingConfigs {
        create("release") {
            storeFile = file(project.property("storeFile") as String)
            storePassword = project.property("storePassword") as String
            keyAlias = project.property("keyAlias") as String
            keyPassword = project.property("keyPassword") as String
        }
    }
    */

    buildTypes {
        release {
            // CAMBIO IMPORTANTE: Usamos la firma 'debug' temporalmente para poder generar el APK
            signingConfig = signingConfigs.getByName("debug")
            
            // Estas opciones ayudan a optimizar, pero a veces causan errores si no están configuradas. 
            // Las dejamos en false por seguridad ahora.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}