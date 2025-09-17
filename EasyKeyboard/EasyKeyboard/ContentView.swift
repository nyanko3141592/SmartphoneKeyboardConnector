//
//  ContentView.swift
//  EasyKeyboard
//
//  Created by 高橋直希 on 2025/09/17.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var inputText = ""
    @State private var showDeviceList = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                HStack {
                    Circle()
                        .fill(bleManager.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)

                    Text(bleManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if bleManager.isConnected {
                        Button("Disconnect") {
                            bleManager.disconnect()
                        }
                        .font(.caption)
                    } else {
                        Button("Connect") {
                            showDeviceList = true
                        }
                        .font(.caption)
                    }
                }
                .padding(.horizontal)

                // Main Input Area
                VStack(spacing: 16) {
                    Text("EasyKeyboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Type on your phone, send to PC")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Text Input Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter Text")
                            .font(.headline)

                        TextEditor(text: $inputText)
                            .frame(minHeight: 150)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .focused($isTextFieldFocused)
                    }
                    .padding(.horizontal)

                    // Send Button
                    Button(action: sendText) {
                        Label("Send to PC", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(bleManager.isConnected ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!bleManager.isConnected || inputText.isEmpty)
                    .padding(.horizontal)

                    // Test Send Button
                    Button(action: sendTestText) {
                        Label("Test Send", systemImage: "testtube.2")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(bleManager.isConnected ? Color.orange : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!bleManager.isConnected)
                    .padding(.horizontal)

                    // Clear Button
                    if !inputText.isEmpty {
                        Button(action: { inputText = "" }) {
                            Label("Clear", systemImage: "xmark.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Keyboard Shortcut Info
                VStack(spacing: 8) {
                    Text("Tip: Press ⌘+Return to send")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showDeviceList) {
            DeviceListView(bleManager: bleManager, isPresented: $showDeviceList)
        }
        .onAppear {
            // Request focus on text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }

    private func sendText() {
        guard !inputText.isEmpty else { return }
        bleManager.sendText(inputText)

        // Clear text after sending
        inputText = ""

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    private func sendTestText() {
        // 簡単な英語テスト文字列
        let testTexts = ["hello", "test", "abc", "123", "Hello World"]
        let randomTest = testTexts.randomElement() ?? "test"

        print("Sending test text: \(randomTest)")
        bleManager.sendText(randomTest)

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// Device List View for BLE device selection
struct DeviceListView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack {
                if bleManager.discoveredDevices.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Searching for devices...")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Make sure your Xiao BLE is powered on")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(bleManager.discoveredDevices, id: \.identifier) { device in
                        Button(action: {
                            bleManager.connect(to: device)
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "keyboard")
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading) {
                                    Text(device.name ?? "Unknown Device")
                                        .font(.headline)
                                    Text(device.identifier.uuidString)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Device")
            .navigationBarItems(
                leading: Button("Cancel") {
                    bleManager.stopScanning()
                    isPresented = false
                },
                trailing: Button(bleManager.isScanning ? "Stop" : "Scan") {
                    if bleManager.isScanning {
                        bleManager.stopScanning()
                    } else {
                        bleManager.startScanning()
                    }
                }
            )
        }
        .onAppear {
            bleManager.startScanning()
        }
        .onDisappear {
            bleManager.stopScanning()
        }
    }
}

#Preview {
    ContentView()
}
