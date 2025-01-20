//
//  Untitled.swift
//  gemHealthKitToFHIR
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.

import Foundation

public enum ConfigurationError : Error {
    case defaultConfigurationBundleNotFound
    case defaultConfigurationNotFound
    case invalidDefaultConfiguration
    case configurationNotFound
    case invalidConfiguration
}
