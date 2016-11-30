//
//  AudioDeviceList.swift
//  aperture
//
//  Created by Khaled Garbaya on 30/11/2016.
//  Copyright © 2016 Wulkano. All rights reserved.
//

//: Playground - noun: a place where people can play

import Cocoa
import CoreAudio
import Foundation
import AVFoundation
import AudioToolbox

class AudioDeviceList {

func getInputDevices() -> [String] {
    
    var inputDevices: [String] = []
    var captureDevices: [AnyObject] = []
    captureDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio)
    
    for device in captureDevices {
        let str: String = "{\"id\": \"\((device.uniqueID as String!))\", \"name\": \"\(device.localizedName)\"}";
        inputDevices.append(str)
    }
    return inputDevices;
}

}
