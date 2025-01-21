//
//  ObservationFactory.swift
//  gemHealthKitToFHIR
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.

import Foundation
import HealthKit
import ModelsR4

/// Class that handles the conversion of Apple HealthKit objects to FHIR.Observation types
open class ObservationFactory : FactoryBase, ResourceFactoryProtocol {
    
    /// Initializes a new ObservationFactory object.
    ///
    /// - Parameters:
    ///   - configName: Optional - The name of a supplimental configuration containing conversion information
    ///   - bundle: Optional - The bundle where the resource is contained.
    /// - Throws:
    ///   - ConfigurationError: Will throw if the config name is not nil and the config cannot be found is is not a valid format.
    public required init(configName: String? = nil, bundle: Foundation.Bundle = Bundle.main) throws {
        super.init()
        try loadDefaultConfiguration()
        try loadConfiguration(configName: configName, bundle: bundle)
    }
    
    public func resource<T>(from object: HKObject) throws -> T {
        guard T.self is Observation.Type else {
            throw ConversionError.incorrectTypeForFactory
        }
        
        return try observation(from: object) as! T
    }
    
    /// Creates a new FHIR.Observation object and populates it using values provided by the given HealthKit sample.
    ///
    /// - Parameters: sample: A HealthKit HKObject.
    /// - Returns: A new FHIR.Observation
    /// - Throws:
    ///   - ConversionError: Will throw if a required value is not mapped properly in the config or the sample type is not supported.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    open func observation(from object: HKObject) throws -> Observation {
        guard let sample = object as? HKSample else {
            // The given type is not currently supported.
            throw ConversionError.unsupportedType(identifier: String(describing: HKObject.self))
        }
        let observation = Observation()
        
        // Add the Observation codes (provided by the lookup in the Config).
        
        observation.code = try self.codeableConcept(objectType: sample.sampleType)
    
        if #available(iOS 14.0, *) {
            if let quantitySample = sample as? HKQuantitySample {
                // The sample is a quantity sample - create a valueQuantity (conversion data provided in the Config).
                observation.valueQuantity = try self.valueQuantity(quantitySample: quantitySample)
            }
            else if let correlation = sample as? HKCorrelation {
                // The sample is a correlation - create components with the appropriate values (conversion data provided in the Config).
                observation.component = try self.component(correlation: correlation)
            }
            else if let category = sample as? HKCategorySample{
                // The sample is a category  - Category samples displayed as codeable concepts
                
                observation.valueCodeableConcept = try self.valueCodeableConcept(categorySample: category.sampleType, value: String(category.value))
            }
            else if let audio = sample as? HKAudiogramSample{
                // The sample is a Audiogram - Audiogram samples displayed as Jsons in a String because of 3 dimensions left, right, frequency
                observation.valueString = try self.valueString(audioSensitivityPoints: audio.sensitivityPoints)
            }
            else if let workout = sample as? HKWorkout{
                // The sample is a Workout
                observation.component = try self.component(workout: workout)
                //overwrite Code with given value for activity type
                
                
                observation.code = try self.valueCodeableConcept(categorySample: workout.sampleType, value: String(workout.workoutActivityType.rawValue), subType: "workoutActivityType")
            }
            else
            {
                // The sample type is not currently supported.
                throw ConversionError.unsupportedType(identifier: sample.sampleType.identifier)
            }
        } else {
            // Fallback on earlier versions
            if let quantitySample = sample as? HKQuantitySample {
                // The sample is a quantity sample - create a valueQuantity (conversion data provided in the Config).
                observation.valueQuantity = try self.valueQuantity(quantitySample: quantitySample)
            }
            else if let correlation = sample as? HKCorrelation {
                // The sample is a correlation - create components with the appropriate values (conversion data provided in the Config).
                observation.component = try self.component(correlation: correlation)
            }
            else if let category = sample as? HKCategorySample{
                // The sample is a category  - Category samples displayed as codeable concepts
                
                observation.valueCodeableConcept = try self.valueCodeableConcept(categorySample: category.sampleType, value: String(category.value))
            }
            else
            {
                // The sample type is not currently supported.
                throw ConversionError.unsupportedType(identifier: sample.sampleType.identifier)
            }
        }
        // Add the HealthKit Identifier
        observation.identifier = [try self.identifier(system: FactoryBase.healthKitIdentifierSystemKey, value: sample.uuid.uuidString)]
    
        
        
        // Set the effective date
        let effective = try self.effective(sample: sample)
        observation.effectiveDateTime = effective as? DateTime ?? observation.effectiveDateTime
        observation.effectivePeriod = effective as? Period ?? observation.effectivePeriod
        
        // Set the Metadata as json String in a component
        if let metadata = sample.metadata{
            try self.metaComponent(observation: observation, metadata: sample.metadata ?? ["":""], sampleTypeDescription: sample.sampleType.description)
        }
        return observation
    }
    
    
    /// Creates a new FHIR.Observation object and populates it using values provided by the given HealthKit ECG.
    ///
    /// - Parameters: sample: A HealthKit HKObject.
    /// - Parameters: measurements for ecg
    /// - Parameters: measirementUnit for measurements
    /// - Returns: A new FHIR.Observation
    /// - Throws:
    ///   - ConversionError: Will throw if a required value is not mapped properly in the config or the sample type is not supported.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    open func observation(from object: HKObject, measurements : String, measurementUnit :String) throws -> Observation {
        guard let sample = object as? HKSample else {
            // The given type is not currently supported.
            throw ConversionError.unsupportedType(identifier: String(describing: HKObject.self))
        }
        
        let observation = Observation()
        if #available(iOS 14.0, *) {
            if let ecg = sample as? HKElectrocardiogram{
                // ECG processing into components.
                observation.component = try self.component(ecg: ecg, measurements: measurements)
            }
            else
            {
                // The sample type is not currently supported.
                throw ConversionError.unsupportedType(identifier: sample.sampleType.identifier)
            }
            
        } else {
            // Fallback on earlier versions
        }
        // Add the HealthKit Identifier
        observation.identifier = [try self.identifier(system: FactoryBase.healthKitIdentifierSystemKey, value: sample.uuid.uuidString)]
        // Add the Observation codes (provided by the lookup in the Config).
        observation.code = try self.codeableConcept(objectType: sample.sampleType)
        // Set the effective date
        let effective = try self.effective(sample: sample)
        observation.effectiveDateTime = effective as? DateTime ?? observation.effectiveDateTime
        observation.effectivePeriod = effective as? Period ?? observation.effectivePeriod
        // Set the Metadata as json String in a component
        if let metadata = sample.metadata{
            try self.metaComponent(observation: observation, metadata: sample.metadata ?? ["":""], sampleTypeDescription: sample.sampleType.description)
        }
        return observation
    }
    
    /// Function for creating FHIR observations based on NSObject (HKWheelchairUse, HKBloodTypeObject, HKFitpatrickSkinType)
    /// - Parameter object: object to parse HKWheelchairUse, HKBloodTypeObject, HKFitpatrickSkinType
    /// - Returns: FHIR observation
    open func observation(object: NSObject) throws -> Observation{
        let observation = Observation()
        if let wheelChair = object as? HKWheelchairUseObject{
            // Add the Observation codes (provided by the lookup in the Config).
            observation.code = try self.codeableConcept(type: "HKCharacteristicTypeIdentifier", subType: "wheelchairUse")
            observation.valueCodeableConcept = try self.valueCodeableConcept(type: "HKCharacteristicTypeIdentifier",
                                                                             value: String(wheelChair.wheelchairUse.rawValue),
                                                                             subType: "wheelchairUse")
        }
        else if let bloodType = object as? HKBloodTypeObject{
            // Add the Observation codes (provided by the lookup in the Config).
            observation.code = try self.codeableConcept(type: "HKCharacteristicTypeIdentifier", subType: "bloodType")
            observation.valueCodeableConcept = try self.valueCodeableConcept(type: "HKCharacteristicTypeIdentifier",
                                                                             value: String(bloodType.bloodType.rawValue),
                                                                             subType: "bloodType")
        }
        else if let fitzpatrickSkinType = object as? HKFitzpatrickSkinTypeObject{
            // Add the Observation codes (provided by the lookup in the Config).
            observation.code = try self.codeableConcept(type: "HKCharacteristicTypeIdentifier", subType: "fitzpatrickSkinType")
            observation.valueCodeableConcept = try self.valueCodeableConcept(type: "HKCharacteristicTypeIdentifier",
                                                                             value: String(fitzpatrickSkinType.skinType.rawValue),
                                                                             subType: "fitzpatrickSkinType")
        }
        else{
            // The sample type is not currently supported.
            throw ConversionError.unsupportedType(identifier: "HKHealhStore not HKWheelchairUse, HKBloodTypeObject, HKFitpatrickSkinType")
        }
        // Add the HealthKit Identifier
        // Create uuid is needed for identification and non double creation.
        
        observation.category = try [self.codeableConcept(type: "Laboratory")]
        
        return observation
        
    }
    
    
    /// Creates a FHIR.CodeableConcept for a given HKObjectType
    ///
    /// - Parameter objectType: The HealthKit object type
    /// - Returns: A new FHIR.CodeableConcept
    /// - Throws:
    ///   - ConversionError: Will throw if the Config does not contain conversion information for the given type or a required value is not provided.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    open func codeableConcept(objectType: HKObjectType, subType: String = "") throws -> CodeableConcept {
        var identifier = objectType.identifier
        if subType != ""{
            identifier = objectType.identifier + "." + subType
        }
        guard let conversionValues = conversionMap[identifier] else {
            throw ConversionError.conversionNotDefinedForType(identifier: identifier)
        }
        guard let json = conversionValues[Constants.codeKey] else {
            throw ConversionError.requiredConversionValueMissing(key: Constants.codeKey)
        }
        // handle object Type identifier as text for Codeable Concept in order to identify concept of apple healthKit
        var ret_codeableConcept = try CodeableConcept(json : json)
        ret_codeableConcept.text = FHIRString(identifier)
        return ret_codeableConcept
    }
    
    /// Creates a FHIR.CodeableConcept for a given HealthStore Type
    ///
    /// - Parameter Type: The HealthStore object type
    /// - Parameter subType: The HealthStore subType
    /// - Returns: A new FHIR.CodeableConcept
    /// - Throws:
    ///   - ConversionError: Will throw if the Config does not contain conversion information for the given type or a required value is not provided.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    open func codeableConcept(type: String = "", subType: String = "") throws -> CodeableConcept {
        var identifier = type
        if subType != ""{
            identifier = type + "." + subType
        }
        guard let conversionValues = conversionMap[identifier] else {
            throw ConversionError.conversionNotDefinedForType(identifier: identifier)
        }
        guard let json = conversionValues[Constants.codeKey] else {
            throw ConversionError.requiredConversionValueMissing(key: Constants.codeKey)
        }
        // handle object Type identifier as text for Codeable Concept in order to identify concept of apple healthKit
        var ret_codeableConcept = try CodeableConcept(json : json)
        ret_codeableConcept.text = FHIRString(identifier)
        return ret_codeableConcept
    }
    
    /// Creates a FHIR.CodeableConcept for a given HKHealthstore
    ///
    /// - Parameter type: The HealthKit object type
    /// - Parameter value: Category value for code.
    /// - Parameter subType: subType for HKWheelchairUse, HKBloodTypeObject, HKFitpatrickSkinType
    /// - Returns: A new FHIR.CodeableConcept
    /// - Throws:
    ///   - ConversionError: Will throw if the Config does not contain conversion information for the given type or a required value is not provided.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    open func valueCodeableConcept(type: String, value: String, subType : String = "") throws -> CodeableConcept {
        // Make all functions like this !!!!!
        var identifier = type
        if subType != ""{
            identifier = type + "." + subType
        }
        guard let conversionValues = conversionMap[identifier] else {
                throw ConversionError.conversionNotDefinedForType(identifier: identifier)
        }
        guard let json = conversionValues[Constants.codeKey] else {
            throw ConversionError.requiredConversionValueMissing(key: Constants.codeKey)
        }
        // handle object Type identifier as text for Codeable Concept in order to identify concept of apple healthKit
        // extract coding based on default config.
        let tmp_codeableConcept = try CodeableConcept(json : json)
        var ret_coding = Coding()
        for tmp_coding in tmp_codeableConcept.coding ?? []{
            if let tmp_code = tmp_coding.code{
                if tmp_code.string == value{
                    ret_coding = tmp_coding
                }
            }
        }
        // handle object Type identifier as text for Codeable Concept in order to identify concept of apple healthKit
        var ret_codeableConcept = try CodeableConcept()
        // Assign value based concept as value of the codeable concept.
        ret_codeableConcept.text = FHIRString(identifier)
        ret_codeableConcept.coding = [Coding]()
        ret_codeableConcept.coding?.append(ret_coding)
        return ret_codeableConcept
        
       
    }
    
    /// Creates a FHIR.CodeableConcept for a given HKObjectType
    ///
    /// - Parameter objectType: The HealthKit object type
    /// - Parameter value: Category value for code.
    /// - Parameter subType: subType for ECG, Audiosample etc.
    /// - Returns: A new FHIR.CodeableConcept
    /// - Throws:
    ///   - ConversionError: Will throw if the Config does not contain conversion information for the given type or a required value is not provided.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    open func valueCodeableConcept(categorySample: HKObjectType, value: String, subType : String = "") throws -> CodeableConcept {
        // Make all functions like this !!!!!
        var identifier = categorySample.identifier
        if subType != ""{
            identifier = categorySample.identifier + "." + subType
        }
        guard let conversionValues = conversionMap[identifier] else {
                throw ConversionError.conversionNotDefinedForType(identifier: identifier)
        }
        guard let json = conversionValues[Constants.codeKey] else {
            throw ConversionError.requiredConversionValueMissing(key: Constants.codeKey)
        }
        // handle object Type identifier as text for Codeable Concept in order to identify concept of apple healthKit
        // extract coding based on default config.
        let tmp_codeableConcept = try CodeableConcept(json : json)
        var ret_coding = Coding()
        for tmp_coding in tmp_codeableConcept.coding ?? []{
            if let tmp_code = tmp_coding.code{
                if tmp_code.string == value{
                    ret_coding = tmp_coding
                }
            }
        }
        // handle object Type identifier as text for Codeable Concept in order to identify concept of apple healthKit
        var ret_codeableConcept = try CodeableConcept()
        // Assign value based concept as value of the codeable concept.
        ret_codeableConcept.text = FHIRString(identifier)
        ret_codeableConcept.coding = [Coding]()
        ret_codeableConcept.coding?.append(ret_coding)
        return ret_codeableConcept
        
       
    }

    
    
    /// Creates a FHIR.Quantity for the given HKQuantitySample
    ///
    /// - Parameter quantitySample: A HealthKit HKQuantitySample
    /// - Parameter subType: for selection of subtype specific quantities based on config
    /// - Returns: A new FHIR.Quantity
    /// - Throws:
    ///   - ConversionError: Will throw if the Config does not contain conversion information for the given type or a required value is not provided.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    open func valueQuantity(quantitySample: HKQuantitySample, subType: String = "") throws -> Quantity {
        var identifier = quantitySample.quantityType.identifier
        if subType != ""{
            identifier = quantitySample.quantityType.identifier + "." + subType
        }

        guard let conversionValues = conversionMap[identifier] else {
            throw ConversionError.conversionNotDefinedForType(identifier: identifier)
        }
        guard var json = conversionValues[Constants.valueQuantityKey] else {
            throw ConversionError.requiredConversionValueMissing(key: Constants.valueQuantityKey)
        }
        // handle object Type identifier as text for Codeable Concept in order to identify concept of apple healthKit
        let defaultUnit = quantitySample.quantity.value(forKey: Constants.unitKey) as! HKUnit
        json[Constants.valueKey] = quantitySample.quantity.doubleValue(for: defaultUnit)
        json[Constants.unitKey] = defaultUnit.unitString
        return try Quantity(json: json)
    }
    
    /// Creates a FHIR.Quantity for the given HKQuantity
    ///
    /// - Parameter quantity: A HealthKit HKQuantity
    /// - Parameter subType: for selection of subtype specific quantities based on config
    /// - Parameter sampleType: submitted sampleType of underlying structure for quantity
    /// - Returns: A new FHIR.Quantity
    /// - Throws:
    ///   - ConversionError: Will throw if the Config does not contain conversion information for the given type or a required value is not provided.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    open func valueQuantity(quantity: HKQuantity, sampleType: HKObjectType , subType: String = "") throws -> Quantity {
        var identifier = sampleType.identifier
        if subType != ""{
            identifier = sampleType.identifier + "." + subType
        }

        guard let conversionValues = conversionMap[identifier] else {
            throw ConversionError.conversionNotDefinedForType(identifier: identifier)
        }
        guard var json = conversionValues[Constants.valueQuantityKey] else {
            throw ConversionError.requiredConversionValueMissing(key: Constants.valueQuantityKey)
        }
        // handle object Type identifier as text for Codeable Concept in order to identify concept of apple healthKit
        let defaultUnit = quantity.value(forKey: Constants.unitKey) as! HKUnit
        json[Constants.valueKey] = quantity.doubleValue(for: defaultUnit)
        json[Constants.unitKey] = defaultUnit.unitString
        return try Quantity(json: json)
    }
    
    /// Creates a FHIR.Quantity for the given double value
    ///
    /// - Parameter value: A HealthKit HKQuantity
    /// - Parameter subType: for selection of subtype specific quantities based on config
    /// - Parameter sampleType: submitted quantityType of underlying structure for quantity
    /// - Returns: A new FHIR.Quantity
    /// - Throws:
    ///   - ConversionError: Will throw if the Config does not contain conversion information for the given type or a required value is not provided.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    open func valueQuantity(value: Double, sampleType: HKObjectType , subType: String = "") throws -> Quantity {
        var identifier = sampleType.identifier
        if subType != ""{
            identifier = sampleType.identifier + "." + subType
        }
        guard let conversionValues = conversionMap[identifier] else {
            throw ConversionError.conversionNotDefinedForType(identifier: identifier)
        }
        guard var json = conversionValues[Constants.valueQuantityKey] else {
            throw ConversionError.requiredConversionValueMissing(key: Constants.valueQuantityKey)
        }
        // handle object Type identifier as text for Codeable Concept in order to identify concept of apple healthKit
        json[Constants.valueKey] = value
        return try Quantity(json: json)
    }
    
    
    @available(iOS 13.0, *)
    /// Function for converting AudiogramSensitivityPoints to Json String
    /// - Parameter audioSensitivityPoints: audiogramSensitivityPoints to convert
    /// - Returns: Json String reprasentation for submitted audioSensitivityPoints.
    open func valueString(audioSensitivityPoints: [HKAudiogramSensitivityPoint])throws -> FHIRString{
        if let audioSensitivity = audioSensitivityPoints as? [HKAudiogramSensitivityPoint]{
            var array = [[String:Any]]()
            for entry in audioSensitivity{
                let frequencyUnit = (entry.frequency.value(forKey: "unit") as! HKUnit).unitString
                let leftEarSensitivityUnit = (entry.leftEarSensitivity?.value(forKey: "unit") as! HKUnit).unitString
                let rightEarSensitivityUnit = (entry.rightEarSensitivity?.value(forKey: "unit") as! HKUnit).unitString
                let left = entry.leftEarSensitivity?.doubleValue(for: HKUnit(from: leftEarSensitivityUnit)) ?? -1.0
                let right = entry.rightEarSensitivity?.doubleValue(for: HKUnit(from: rightEarSensitivityUnit)) ?? -1.0


                var audiogramsensitivity : [String : Any] = [
                    "frequency": [
                        "quantity": [
                            "value": String(format: "%f", entry.frequency.doubleValue(for: HKUnit(from: frequencyUnit))),
                            "unit": frequencyUnit
                        ]
                    ],
                    "leftEarSensitivity": [
                        "quantity":[
                            "value": String(format: "%f", left),
                            "unit": leftEarSensitivityUnit
                        ]
                    ],
                    "rightEarSensitivity": [
                        "quantity":[
                            "value": String(format: "%f", right),
                            "unit": rightEarSensitivityUnit
                        ]
                    ]
                ]
                array.append(audiogramsensitivity)

            }
            
            let audigramsensitivityJsonObject = try JSONSerialization.data(withJSONObject: array, options: [])
            // Convert NSData to String
            let audiogramsensitivityJsonObjectString = String(data: audigramsensitivityJsonObject, encoding: String.Encoding.utf8) ?? ""
            return FHIRString(audiogramsensitivityJsonObjectString)
        }
    }
    
    /// Function for converting WorkoutEvents to Json String
    /// - Parameter workoutEvents: workoutEvents to convert
    /// - Returns: Json String reprasentation for submitted audioSensitivityPoints.
    open func valueString(workoutEvents: [HKWorkoutEvent])throws -> FHIRString{
        if let workoutEvent = workoutEvents as? [HKWorkoutEvent]{
            let lookup = [
                "HKWorkout.workoutEvent.type":[
                    1 : "pause",
                    2 : "resume",
                    3 : "lap",
                    4 : "marker",
                    5 : "motionPaused",
                    6 : "motionResumed",
                    7 : "segment",
                    8 : "pauseOrResumeRequest"
                ]

            ]
            var array = [[String:Any]]()
            for event in workoutEvent{
                let unwrapped_metadataEventString = event.metadata?.description ?? ""
                var displayValueEventType = ""
                for (key, value) in lookup{
                    if key.contains("HKWorkout.workoutEvent.type"){
                        displayValueEventType = value[event.type.rawValue] ?? ""
                    }
                }
                let dictionaryOfWorkouts : [String : Any] = [
                    "dateInterval": [
                        "start": dateFormatter.string(from: event.dateInterval.start),
                        "end": dateFormatter.string(from: event.dateInterval.end),
                        "duration": event.dateInterval.duration
                    ],
                    "type": displayValueEventType,
                    "metadata": unwrapped_metadataEventString
                ]
                array.append(dictionaryOfWorkouts)
            }
            
            
            let workouteventJsonObject = try JSONSerialization.data(withJSONObject: array, options: [])
            
            // Convert NSData to String
            let workouteventJsonObjectString = String(data: workouteventJsonObject, encoding: String.Encoding.utf8) ?? ""
            return FHIRString(workouteventJsonObjectString)
        }
    }
    
    
    
    
    
    
    /// Creates a new collection of FHIR.ObservationComponents
    ///
    /// - Parameter correlation: A Healthkit HKCorrelation
    /// - Returns: a new FHIR.ObservationComponent collection
    /// - Throws:
    ///   - ConversionError: Will throw if the Config does not contain conversion information for the given type or a required value is not provided.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    open func component(correlation: HKCorrelation ) throws -> [ObservationComponent] {
        var components: [ObservationComponent] = []
        
        for sample in correlation.objects {
            if let quantitySample = sample as? HKQuantitySample {
                let codeableConcept = try self.codeableConcept(objectType: quantitySample.sampleType)
                let component = ObservationComponent(code: codeableConcept)
                component.valueQuantity = try valueQuantity(quantitySample: quantitySample)
                components.append(component)
            }
            else
            {
                throw ConversionError.conversionNotDefinedForType(identifier: sample.sampleType.identifier)
            }
        }
        
        return components
    }
    
    /// Creates a new collection of FHIR.ObservationComponents
    ///
    /// - Parameter ecg: A Healthkit HKElectrocardiogram
    /// - Returns: a new FHIR.ObservationComponent collection
    /// - Throws:
    ///   - ConversionError: Will throw if the Config does not contain conversion information for the given type or a required value is not provided.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    @available(iOS 14.0, *)
    open func component(ecg: HKElectrocardiogram, measurements: String = "") throws -> [ObservationComponent] {
        var components: [ObservationComponent] = []
        
        //var json = conversionMap["HKElectrocardiogram"]

        if let symptomsStatus = ecg.symptomsStatus as? HKElectrocardiogram.SymptomsStatus{
            // create Component based on symptomsStatus
            var component = ObservationComponent()
            // set code of component
            component.code = try self.codeableConcept(objectType: ecg.sampleType, subType: "symptomsStatus")
            // set value of component
            component.valueCodeableConcept = try self.valueCodeableConcept(categorySample: ecg.sampleType, value: String(symptomsStatus.rawValue), subType: "symptomsStatus")
            // append component to components
            components.append(component)
        }
        if let classification = ecg.classification as? HKElectrocardiogram.Classification{
            // create Component based on classification
            var component = ObservationComponent()
            // set code of component
            component.code = try self.codeableConcept(objectType: ecg.sampleType, subType: "classification")
            // set value of component
            component.valueCodeableConcept = try self.valueCodeableConcept(categorySample: ecg.sampleType, value: String(classification.rawValue), subType: "classification")
            // append component to components
            components.append(component)
        }
        if let samplingFrequency = ecg.samplingFrequency{
            // Create Component based on sampling frequency and measurements
            // period = 1/samplingFrequency * 1000
            var component = ObservationComponent()
            // set code of component
            component.code = try self.codeableConcept(objectType: ecg.sampleType, subType: "measurements")
            let samplingFrequencyUnit = samplingFrequency.value(forKey: Constants.unitKey) as! HKUnit
            var valueSampledData = SampledData()
            var origin = Quantity()
            origin.value = 0
            valueSampledData.origin = origin
            valueSampledData.dimensions = FHIRInteger("1")
            valueSampledData.data = FHIRString(measurements)
            let period = ((1/samplingFrequency.doubleValue(for: samplingFrequencyUnit))*1000)
            valueSampledData.period = FHIRDecimal(String(period))
            component.valueSampledData = valueSampledData
            components.append(component)
            
        }
        if let averageHeartRate = ecg.averageHeartRate{
            // create Component based on average heart rate
            var component = ObservationComponent()
            // set code of component
            component.code = try self.codeableConcept(objectType: ecg.sampleType, subType: "averageHeartRate")
            // set value of component
            component.valueQuantity = try self.valueQuantity(quantity: averageHeartRate,
                                                             sampleType: ecg.sampleType,
                                                             subType: "averageHeartRate")
            // append component to components
            components.append(component)
        }
     
        
        return components
    }
    
    /// Creates a new collection of FHIR.ObservationComponents
    ///
    /// - Parameter ecg: A Healthkit HKWorkout
    /// - Returns: a new FHIR.ObservationComponent collection
    /// - Throws:
    ///   - ConversionError: Will throw if the Config does not contain conversion information for the given type or a required value is not provided.
    ///   - FHIRValidationError: Will throw if the conversion process yeilds an invalid FHIR object.
    @available(iOS 14.0, *)
    open func component(workout: HKWorkout) throws -> [ObservationComponent] {
        var components: [ObservationComponent] = []
        
        if let workoutEvents = workout.workoutEvents as? [HKWorkoutEvent]{
            // create component based on HKWorkoutEvent array - array will be json string.
            var component = ObservationComponent()
            // set code of component
            component.code = try self.codeableConcept(objectType: workout.sampleType, subType: "workoutEvents")
            // set value of component
            component.valueString = try self.valueString(workoutEvents: workoutEvents)
            // append component to components
            components.append(component)
        }
        if let duration = workout.duration as? TimeInterval{
            // duration of Workout
            var component = ObservationComponent()
            // set code of component
            component.code = try self.codeableConcept(objectType: workout.sampleType, subType: "duration")
            // set value of component
            component.valueQuantity = try self.valueQuantity(value: duration, sampleType: workout.sampleType, subType: "duration")
            // append component to components
            components.append(component)
        }
        if let totalDistance = workout.totalDistance as? HKQuantity{
            // total distance of Workout
            var component = ObservationComponent()
            // set code of component
            component.code = try self.codeableConcept(objectType: workout.sampleType, subType: "totalDistance")
            // set value of component
            component.valueQuantity = try self.valueQuantity(quantity: totalDistance,
                                                             sampleType: workout.sampleType,
                                                             subType: "totalDistance")
            // append component to components
            components.append(component)
        }
        if let totalEnergyBurned = workout.totalEnergyBurned as? HKQuantity{
            // total energy burned of Workout
            var component = ObservationComponent()
            // set code of component
            component.code = try self.codeableConcept(objectType: workout.sampleType, subType: "totalEnergyBurned")
            // set value of component
            component.valueQuantity = try self.valueQuantity(quantity: totalEnergyBurned,
                                                             sampleType: workout.sampleType,
                                                             subType: "totalEnergyBurned")
            // append component to components
            components.append(component)
        }
        if let totalFlightsClimbed = workout.totalFlightsClimbed as? HKQuantity{
            // total flights climbed of Workout
            var component = ObservationComponent()
            // set code of component
            component.code = try self.codeableConcept(objectType: workout.sampleType, subType: "totalFlightsClimbed")
            // set value of component
            component.valueQuantity = try self.valueQuantity(quantity: totalFlightsClimbed,
                                                             sampleType: workout.sampleType,
                                                             subType: "totalFlightsClimbed")
            // append component to components
            components.append(component)
        }
        if let totalSwimmingStrokeCount = workout.totalSwimmingStrokeCount as? HKQuantity{
            // total swimming strokes of Workout
            var component = ObservationComponent()
            // set code of component
            component.code = try self.codeableConcept(objectType: workout.sampleType, subType: "totalSwimmingStrokeCount")
            // set value of component
            component.valueQuantity = try self.valueQuantity(quantity: totalSwimmingStrokeCount,
                                                             sampleType: workout.sampleType,
                                                             subType: "totalSwimmingStrokeCount")
            // append component to components
            components.append(component)
        }
        
        return components
    }
    
    /// Creates a new Component with meta informations.
    ///
    /// - Parameter observation: observation to add component to
    /// - Parameter metadata: metadata metadata to add.
    /// - Parameter sampleTypeDescription: sampleTypeDescription description
    open func metaComponent(observation: Observation , metadata: [String : Any], sampleTypeDescription: String) throws{
        
        // craft codeableConcept
        var codeableConcept = FHIR.CodeableConcept()
        let system = Constants.healthAppBundleId + "." + sampleTypeDescription + ".metadata"
        var coding = FHIR.Coding()
        coding.display = FHIRString("Metadata")
        coding.system = FHIRURL(system)
        codeableConcept.coding = [Coding]()
        codeableConcept.coding?.append(coding)
        codeableConcept.text = FHIRString(sampleTypeDescription + ".metadata")
        var obsComponent = ObservationComponent()
        obsComponent.valueString = FHIRString(metadata.description ?? "")
        // add everything together
        obsComponent.code = codeableConcept
        if var components = observation.component as? [ObservationComponent]{
            components.append(obsComponent)
            observation.component = components
        }else{
            var components = [ObservationComponent]()
            components.append(obsComponent)
            observation.component = components
        }
    }
    
    
    /// Creates a FHIR.DateTime if the start and end dates of the sample are the same or a FHIR.Period if they are different.
    ///
    /// - Parameter sample: A HealthKit HKSample
    /// - Returns: A new FHIR.DateTime or a FHIR.Period
    /// - Throws:
    ///   - ConversionError: Will throw if the Date cannot be converted to either a FHIR.DateTime or a FHIR.Period
    open func effective(sample: HKSample) throws -> Any {
        let timeZoneString = sample.metadata?[HKMetadataKeyTimeZone] as? String
        
        if (sample.startDate == sample.endDate),
            let dateTime = dateTime(date: sample.startDate, timeZoneString: timeZoneString) {
                return dateTime
        }
        
        if let start = dateTime(date: sample.startDate, timeZoneString: timeZoneString),
            let end = dateTime(date: sample.endDate, timeZoneString: timeZoneString) {
            let period = Period()
            period.start = start
            period.end = end
            
            return period
        }
        
        throw ConversionError.dateConversionError
    }
    
    private func loadDefaultConfiguration() throws {
        do {
            // Initialize a data object with the contents of the file.
            let data = Configurations.defaultConfig.data(using: .utf8)
            
            guard data != nil else {
                throw ConfigurationError.invalidDefaultConfiguration
            }
            
            try loadConfiguration(data: data!)
            
        } catch {
            // The configuration was not formatted correctly.
            throw ConfigurationError.invalidDefaultConfiguration
        }
    }
}
