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

func getInputDevices() -> NSString? {
    
    var inputDevices: [[String:String]] = []
    let captureDevices: [AnyObject] = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio) as [AnyObject]
    
    for device in captureDevices {
        let obj: AnyObject = ["id": (device.uniqueID as String!), "name":(device.localizedName)]
        inputDevices.append(obj as! [String : String])
    }
    
    do {
        let parsedData = try NSJSONSerialization.dataWithJSONObject(inputDevices, options: [])
        return NSString(data: parsedData, encoding: NSUTF8StringEncoding)
    } catch _ as NSError {
        return nil
    }
}

}
