import SwiftUI

struct CoffeeShopDashboardView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Background image with top navigation
            ZStack(alignment: .top) {
                // Background cafe image
                Image("cafeBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 250)
                    .clipped()
                
                // Top navigation buttons
                HStack {
                    Button(action: {}) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "doc.text")
                                    .foregroundColor(.black)
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(.black)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Revenue card
                VStack(alignment: .leading, spacing: 4) {
                    Text("Doanh thu hôm nay")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .center) {
                        Image(systemName: "diamond.fill")
                            .foregroundColor(.blue)
                        
                        Text("16,323,234 đ")
                            .font(.system(size: 22, weight: .bold))
                    }
                    
                    HStack {
                        Text("Powered by")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("napas")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .offset(y: 200)
            }
            .frame(height: 280)
            
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Shop info
                    HStack(spacing: 12) {
                        // Shop logo
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "leaf")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 24))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Phê La Hàng Cót")
                                    .font(.system(size: 20, weight: .bold))
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            Text("141 Hàng Cót, Hoàn kiếm, Hà Nội")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 20)
                    
                    // Today's orders section
                    VStack(spacing: 0) {
                        HStack {
                            Text("Hôm nay")
                                .font(.system(size: 18, weight: .medium))
                            
                            Spacer()
                            
                            Button(action: {}) {
                                HStack(spacing: 4) {
                                    Text("Xem tất cả")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        
                        // Order items
                        ForEach(0..<2) { _ in
                            VStack(spacing: 0) {
                                Divider()
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Đơn hàng #10093998")
                                            .font(.system(size: 16, weight: .medium))
                                        
                                        HStack {
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 14))
                                            
                                            Text("17:45")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 8) {
                                        Text("+11,500,000 đ")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.green)
                                        
                                        Text("Smile Pay **** 0213")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    // Bank promo banner
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.yellow)
                            .cornerRadius(16)
                            .frame(height: 100)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tài khoản số đẹp như ý")
                                    .font(.system(size: 18, weight: .bold))
                                
                                Text("Lộc liền tay với tài khoản số\nđẹp dành riêng cho cửa hàng")
                                    .font(.system(size: 14))
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Text("PVcomBank")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            
            // Bottom create order button
            Button(action: {}) {
                HStack {
                    Image(systemName: "plus")
                    Text("Tạo đơn hàng")
                        .font(.system(size: 18, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(UIColor.darkGray))
                .cornerRadius(30)
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
            .background(Color.white)
        }
        .edgesIgnoringSafeArea(.top)
        .background(Color(UIColor.systemGray6))
    }
}

struct CoffeeShopDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        CoffeeShopDashboardView()
    }
}