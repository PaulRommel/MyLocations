//
//  AppDelegate.swift
//  MyLocations
//
//  Created by Павел Попов on 08.11.2026.
//

import UIKit
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // Глава 27 "Saving Locations": Core Data stack на базе
    // NSPersistentContainer — он сам находит файл модели MyLocations.xcdatamodeld
    // по имени, создаёт SQLite-хранилище при первом запуске и отдаёт
    // единый контекст (viewContext) для чтения/записи на главном потоке.
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MyLocations")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // Если хранилище не удалось открыть (повреждённый файл,
                // несовместимая модель и т.п.) — это ошибка уровня запуска
                // приложения, продолжать работу бессмысленно.
                fatalError("Unresolved error loading persistent stores: \(error), \(error.userInfo)")
            }
        }
        return container
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

