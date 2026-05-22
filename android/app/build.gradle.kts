import java.util.Properties
import java.io.FileInputStream
import kotlin.io.path.exists

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.firebase.crashlytics")
}

// Carregamento das propriedades da chave (key.properties)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.luan1990dev.reedu"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Necessário para as notificações e APIs de tempo (java.time)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.luan1990dev.reedu"
        minSdk = flutter.minSdkVersion
        targetSdk = 35

        // DICA: Lembre-se de aumentar o versionCode para cada novo envio ao Google
        versionCode = 31
        versionName = "1.0.8.31"

        multiDexEnabled = true
    }

    // CONFIGURAÇÃO DE ASSINATURA (ADICIONADO)
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        // CONFIGURAÇÃO DE LANÇAMENTO AJUSTADA
        getByName("release") {
            // Define a assinatura de produção criada acima
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = false
            isShrinkResources = false
        }

        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Essencial para o agendamento de alarmes precisos
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-crashlytics")
}
