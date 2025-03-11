//
//  TranslationManager.swift
//  YOLO
//
//  Created as part of the Tono integration
//

import Foundation

/// Manager for handling translations of detected objects
class TranslationManager {
    static let shared = TranslationManager()
    
    // Dictionary to store translations: [English: (Chinese, Pinyin)]
    private var translations: [String: (chinese: String, pinyin: String)] = [:]
    
    // COCO class names used by YOLO models
    private let cocoClassNames = [
        "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
        "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
        "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
        "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
        "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle",
        "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich",
        "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
        "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote",
        "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book",
        "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
    ]
    
    private init() {
        loadTranslations()
    }
    
    /// Load translations from a JSON file or create default ones
    private func loadTranslations() {
        // Try to load from a JSON file if it exists
        if let path = Bundle.main.path(forResource: "translations", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]],
           let translationsDict = json["translations"] {
            
            // Parse the JSON data
            for item in translationsDict {
                if let dict = item as? [String: String],
                   let english = dict["english"],
                   let chinese = dict["chinese"],
                   let pinyin = dict["pinyin"] {
                    translations[english] = (chinese, pinyin)
                }
            }
            
            print("Loaded \(translations.count) translations from JSON")
        } else {
            // Create default translations for common objects
            createDefaultTranslations()
            print("Created default translations for \(translations.count) objects")
        }
    }
    
    /// Create default translations for common COCO objects
    private func createDefaultTranslations() {
        // Sample translations for common objects
        // In a real app, this would be a complete list loaded from a file
        translations = [
            "person": ("人", "rén"),
            "bicycle": ("自行车", "zìxíngchē"),
            "car": ("汽车", "qìchē"),
            "motorcycle": ("摩托车", "mótuōchē"),
            "airplane": ("飞机", "fēijī"),
            "bus": ("公共汽车", "gōnggòng qìchē"),
            "train": ("火车", "huǒchē"),
            "truck": ("卡车", "kǎchē"),
            "boat": ("船", "chuán"),
            "traffic light": ("红绿灯", "hónglǜdēng"),
            "fire hydrant": ("消防栓", "xiāofáng shuān"),
            "stop sign": ("停止标志", "tíngzhǐ biāozhì"),
            "parking meter": ("停车计时器", "tíngchē jìshí qì"),
            "bench": ("长凳", "chángdèng"),
            "bird": ("鸟", "niǎo"),
            "cat": ("猫", "māo"),
            "dog": ("狗", "gǒu"),
            "horse": ("马", "mǎ"),
            "sheep": ("羊", "yáng"),
            "cow": ("牛", "niú"),
            "elephant": ("大象", "dàxiàng"),
            "bear": ("熊", "xióng"),
            "zebra": ("斑马", "bānmǎ"),
            "giraffe": ("长颈鹿", "chángjǐnglù"),
            "backpack": ("背包", "bēibāo"),
            "umbrella": ("雨伞", "yǔsǎn"),
            "handbag": ("手提包", "shǒutíbāo"),
            "tie": ("领带", "lǐngdài"),
            "suitcase": ("手提箱", "shǒutíxiāng"),
            "frisbee": ("飞盘", "fēipán"),
            "skis": ("滑雪板", "huáxuě bǎn"),
            "snowboard": ("单板滑雪", "dānbǎn huáxuě"),
            "sports ball": ("运动球", "yùndòng qiú"),
            "kite": ("风筝", "fēngzheng"),
            "baseball bat": ("棒球棒", "bàngqiú bàng"),
            "baseball glove": ("棒球手套", "bàngqiú shǒutào"),
            "skateboard": ("滑板", "huábǎn"),
            "surfboard": ("冲浪板", "chōnglàng bǎn"),
            "tennis racket": ("网球拍", "wǎngqiú pāi"),
            "bottle": ("瓶子", "píngzi"),
            "wine glass": ("酒杯", "jiǔbēi"),
            "cup": ("杯子", "bēizi"),
            "fork": ("叉子", "chāzi"),
            "knife": ("刀", "dāo"),
            "spoon": ("勺子", "sháozi"),
            "bowl": ("碗", "wǎn"),
            "banana": ("香蕉", "xiāngjiāo"),
            "apple": ("苹果", "píngguǒ"),
            "sandwich": ("三明治", "sānmíngzhì"),
            "orange": ("橙子", "chéngzi"),
            "broccoli": ("西兰花", "xīlánhuā"),
            "carrot": ("胡萝卜", "húluóbo"),
            "hot dog": ("热狗", "règǒu"),
            "pizza": ("披萨", "pīsà"),
            "donut": ("甜甜圈", "tiántiánquān"),
            "cake": ("蛋糕", "dàngāo"),
            "chair": ("椅子", "yǐzi"),
            "couch": ("沙发", "shāfā"),
            "potted plant": ("盆栽", "pénzāi"),
            "bed": ("床", "chuáng"),
            "dining table": ("餐桌", "cānzhuō"),
            "toilet": ("厕所", "cèsuǒ"),
            "tv": ("电视", "diànshì"),
            "laptop": ("笔记本电脑", "bǐjìběn diànnǎo"),
            "mouse": ("鼠标", "shǔbiāo"),
            "remote": ("遥控器", "yáokòngqì"),
            "keyboard": ("键盘", "jiànpán"),
            "cell phone": ("手机", "shǒujī"),
            "microwave": ("微波炉", "wēibōlú"),
            "oven": ("烤箱", "kǎoxiāng"),
            "toaster": ("烤面包机", "kǎo miànbāo jī"),
            "sink": ("水槽", "shuǐcáo"),
            "refrigerator": ("冰箱", "bīngxiāng"),
            "book": ("书", "shū"),
            "clock": ("时钟", "shízhōng"),
            "vase": ("花瓶", "huāpíng"),
            "scissors": ("剪刀", "jiǎndāo"),
            "teddy bear": ("泰迪熊", "tàidí xióng"),
            "hair drier": ("吹风机", "chuīfēngjī"),
            "toothbrush": ("牙刷", "yáshuā")
        ]
    }
    
    /// Save translations to a JSON file
    func saveTranslations() {
        var jsonArray: [[String: String]] = []
        
        // Convert dictionary to array of dictionaries
        for (english, translation) in translations {
            let item: [String: String] = [
                "english": english,
                "chinese": translation.chinese,
                "pinyin": translation.pinyin
            ]
            jsonArray.append(item)
        }
        
        // Create JSON object
        let json: [String: Any] = ["translations": jsonArray]
        
        // Convert to data
        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            // Get documents directory
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsDirectory.appendingPathComponent("translations.json")
                
                // Write to file
                do {
                    try data.write(to: fileURL)
                    print("Saved translations to \(fileURL.path)")
                } catch {
                    print("Error saving translations: \(error)")
                }
            }
        }
    }
    
    /// Get translation for an English object name
    /// - Parameter english: The English name of the object
    /// - Returns: A tuple containing the Chinese translation and pinyin, or nil if not found
    func getTranslation(for english: String) -> (chinese: String, pinyin: String)? {
        // Try exact match first
        if let translation = translations[english] {
            return translation
        }
        
        // Try case-insensitive match
        let lowercaseEnglish = english.lowercased()
        for (key, value) in translations {
            if key.lowercased() == lowercaseEnglish {
                return value
            }
        }
        
        // Try partial match (for compound words)
        for (key, value) in translations {
            if lowercaseEnglish.contains(key.lowercased()) || key.lowercased().contains(lowercaseEnglish) {
                return value
            }
        }
        
        // No translation found
        return nil
    }
    
    /// Add or update a translation
    /// - Parameters:
    ///   - english: The English name of the object
    ///   - chinese: The Chinese translation
    ///   - pinyin: The pinyin pronunciation
    func addTranslation(english: String, chinese: String, pinyin: String) {
        translations[english] = (chinese, pinyin)
        saveTranslations()
    }
    
    /// Get all available translations
    /// - Returns: Dictionary of all translations
    func getAllTranslations() -> [String: (chinese: String, pinyin: String)] {
        return translations
    }
    
    /// Get all COCO class names
    /// - Returns: Array of COCO class names
    func getCocoClassNames() -> [String] {
        return cocoClassNames
    }
} 