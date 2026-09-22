allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}



subprojects {
    val configureProject = {
        val manifestFile = file("${project.projectDir}/src/main/AndroidManifest.xml")
        if (manifestFile.exists()) {
            try {
                val content = manifestFile.readText()
                if (content.contains("package=")) {
                    val newContent = content.replace(Regex("""package="[^"]*""""), "")
                    manifestFile.writeText(newContent)
                }
            } catch (e: Exception) {}
        }
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            try {
                val getNamespace = androidExtension.javaClass.getMethod("getNamespace")
                val setNamespace = androidExtension.javaClass.getMethod("setNamespace", String::class.java)
                val currentNamespace = getNamespace.invoke(androidExtension)
                if (currentNamespace == null) {
                    val ns = if (project.name == "isar_flutter_libs") {
                        "dev.isar.isar_flutter_libs"
                    } else {
                        "com.inkflow.${project.name.replace("_", ".").replace("-", ".")}"
                    }
                    setNamespace.invoke(androidExtension, ns)
                    println("Dynamically set namespace for subproject ${project.name} to $ns")
                }
            } catch (e: Exception) {
                // Ignore if method not found or other reflection errors
            }
            try {
                val setCompileSdk = androidExtension.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                setCompileSdk.invoke(androidExtension, 36)
            } catch (e: Exception) {}
        }
    }
    if (state.executed) {
        configureProject()
    } else {
        afterEvaluate {
            configureProject()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
