//
//  SharedFileManager.swift
//  reelKeeper
//
//  Created by AlexDelgado on 6/3/25.
//

import Foundation

public class SharedFileManager {
    public static let shared = SharedFileManager()
    
    // Cambia esto por tu App Group
    private let appGroup = "group.com.add.testing.reelKeeper.2"
    // Nombre del fichero principal
    private let fileName = "sharedURLs.json"
    // Nombre del fichero de backup
    private let backupFileName = "sharedURLs.backup.json"
    
    private init() {}
    
    // MARK: - Funciones auxiliares de URL
    
    /// Obtiene la URL del fichero principal en el contenedor compartido.
    private func getFileURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            print("Error: No se pudo obtener la URL del contenedor compartido.")
            return nil
        }
        return containerURL.appendingPathComponent(fileName)
    }
    
    /// Obtiene la URL del fichero de backup en el contenedor compartido.
    private func getBackupFileURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return nil
        }
        return containerURL.appendingPathComponent(backupFileName)
    }
    
    // MARK: - Funciones de lectura y escritura
    
    /// Recupera todas las URLs almacenadas.
    public func getURLItems() -> [SharedURLItem] {
        guard let fileURL = getFileURL() else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([SharedURLItem].self, from: data)
        } catch {
            print("Error leyendo URLs: \(error)")
            return []
        }
    }
    
    /// Elimina una URL por su id.
    public func deleteURL(by id: UUID) {
        var existingItems = getURLItems()
        // Filtra para excluir el ítem con el id indicado.
        existingItems.removeAll { $0.id == id }
        // Guarda la lista actualizada.
        saveURL(existingItems, append: false)
    }
    
    /// Guarda (o actualiza) la lista de ítems en el fichero JSON.
    /// - Parameters:
    ///   - items: Array de SharedURLItem a guardar.
    ///   - append: Si es true se agregan los ítems a los existentes; si es false, se reemplaza la lista.
    public func saveURL(_ items: [SharedURLItem], append: Bool = true) {
        guard let fileURL = getFileURL(), let backupURL = getBackupFileURL() else {
            print("Error: No se pudo obtener la URL del fichero o del backup.")
            return
        }
        
        // Si append es true, se agregan los nuevos items a los existentes.
        var updatedItems = append ? getURLItems() : [SharedURLItem]()
        updatedItems.append(contentsOf: items)
        
        do {
            // Codifica el array a JSON.
            let data = try JSONEncoder().encode(updatedItems)
            
            // Crea el fichero principal si no existe.
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
            }
            
            // Crear copia de seguridad si el fichero existe.
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try FileManager.default.removeItem(at: backupURL)
                }
                try FileManager.default.copyItem(at: fileURL, to: backupURL)
                print("Backup creado en: \(backupURL.path)")
            }
            
            // Intentar escribir el fichero con reintentos.
            let maxAttempts = 4
            var success = false
            for attempt in 1...maxAttempts {
                do {
                    let fileHandle = try FileHandle(forWritingTo: fileURL)
                    defer { fileHandle.closeFile() }
                    
                    // Borrar contenido anterior y escribir los nuevos datos
                    fileHandle.truncateFile(atOffset: 0)
                    fileHandle.write(data)
                    
                    print("Intento \(attempt): Escritura exitosa en \(fileURL.path)")
                    success = true
                    break
                } catch {
                    print("Intento \(attempt): Error al escribir URLs: \(error)")
                    
                    // Si falla, se intenta restaurar el backup antes de reintentar.
                    if FileManager.default.fileExists(atPath: backupURL.path) {
                        do {
                            if FileManager.default.fileExists(atPath: fileURL.path) {
                                try FileManager.default.removeItem(at: fileURL)
                            }
                            try FileManager.default.copyItem(at: backupURL, to: fileURL)
                            print("Intento \(attempt): Backup restaurado.")
                        } catch {
                            print("Intento \(attempt): Error restaurando el backup: \(error)")
                        }
                    }
                }
            }
            
            if success {
                // Si la escritura fue exitosa, eliminar el backup.
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    do {
                        try FileManager.default.removeItem(at: backupURL)
                        print("Backup eliminado tras escritura exitosa.")
                    } catch {
                        print("Error eliminando el backup: \(error)")
                    }
                }
            } else {
                print("No se pudo escribir el fichero después de \(maxAttempts) intentos. El backup se mantiene en: \(backupURL.path)")
            }
            
        } catch {
            print("Error codificando o procesando datos: \(error)")
        }
    }
    
    /// Elimina el fichero de URLs.
    public func clearURLs() {
        if let fileURL = getFileURL() {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("Archivo \(fileURL.path) eliminado correctamente.")
            } catch {
                print("Error eliminando archivo: \(error)")
            }
        }
    }
}
