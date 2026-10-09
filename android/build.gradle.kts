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
    project.evaluationDependsOn(":app")

    val configureProject = {
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            try {
                val getNamespace = androidExtension.javaClass.getMethod("getNamespace")
                val setNamespace = androidExtension.javaClass.getMethod("setNamespace", String::class.java)
                val currentNamespace = getNamespace.invoke(androidExtension)
                if (currentNamespace == null) {
                    val ns = "com.inkflow.${project.name.replace("_", ".").replace("-", ".")}"
                    setNamespace.invoke(androidExtension, ns)
                    println("Dynamically set namespace for subproject ${project.name} to $ns")
                }
            } catch (e: Exception) {
                logger.warn("namespace hack skipped for ${project.name}: $e")
            }
            try {
                val setCompileSdk = androidExtension.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                setCompileSdk.invoke(androidExtension, 36)
            } catch (e: Exception) {
                logger.warn("compileSdk hack skipped for ${project.name}: $e")
            }
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
