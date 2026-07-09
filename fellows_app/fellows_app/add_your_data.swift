//
//  add_your_data.swift
//  fellows_app
//
//  Created by san-12 on 03/07/2026.
//

import SwiftUI

struct add_your_data: View {

    var onOnboardingCompleted: () -> Void = {}
    @State var navigate: Bool = false
    
    var body: some View {
        
        HStack { // per allineare a destra in alto
            Spacer()
            Text("Hi,").font(.custom("SingleDay-Regular", size: 30))
            Spacer()
            Image("tomato_drawn").resizable().frame(width: 250, height: 250).padding(.bottom, 0)
        }

        Text("we need to ask you\nonly a few things\nto set up your experience!").font(.custom("SingleDay-Regular", size: 30))
        
        
        // Spacer()
        .padding(.bottom, 50)

        Button {
            navigate = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.forward.square")
                    .font(.system(size: 17))
                
                Text("next :)")
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
            add_your_data_1(onOnboardingCompleted: onOnboardingCompleted)
        }
        
        Spacer()
        
            }
}

#Preview {
    NavigationStack {
        add_your_data()
    }
}
