//
//  ContentView.swift
//  fellows_app
//
//  Created by san-12 on 02/07/2026.
//

import SwiftUI

struct ContentView: View {

    var onOnboardingCompleted: () -> Void = {}
    @State private var navigate = false
    
    var body: some View { // Welcome page
        NavigationStack {
            VStack {

                Text("Welcome on".uppercased())
                    .font(Font.system(size: 18, weight: .semibold ))
                Image("logo_fellows").resizable().aspectRatio(contentMode: .fill).frame(width: 300, height: 40)
                Image("testo_centrale") // img slogan
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Spacer()
                
                
                    Button {
                        navigate = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.forward.square")
                                .font(.system(size: 17))
                            
                            Text("START NOW")
                                .font(.custom("SingleDay-Regular", size: 24))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 0)
                        .frame(width: 251, height: 67)
                        .background(Color(red: 0.56, green: 0.75, blue: 0.51))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .navigationDestination(isPresented: $navigate) {
                        add_your_data(onOnboardingCompleted: onOnboardingCompleted)
                    }
                    
                    
                    Text("It requires just a few steps!")
                }
                // il padding e' stato aggiunto alla VStack, e non alla navigationStack (per evitare artefizi visivi nelle animazioni di push a transizione pagina)
                .padding(.bottom, 80)
                .padding(.top, 70)
            }
        
    }
}

#Preview {
    ContentView()
}
