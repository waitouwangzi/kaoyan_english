allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.value(file("C:/Users/王连武/build_output/android_build"))

subprojects {
    project.layout.buildDirectory.value(file("C:/Users/王连武/build_output/android_build/${project.name}"))
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(file("C:/Users/王连武/build_output/android_build"))
}
