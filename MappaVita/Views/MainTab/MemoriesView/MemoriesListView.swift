import SwiftUI

// Add enum for time filters
enum TimeFilter {
    case all
    case lastWeek
    case lastMonth
    case lastSixMonths
    case lastYear
}

struct MemoriesListView: View {
    @StateObject private var viewModel = MemoriesViewModel()
    @State private var selectedItem: TimelineItem?
    @State private var showAddMemory = false
    @State private var timeFilter: TimeFilter = .all
    @State private var showStarredOnly = false
    @State private var placeForNewMemory: Place? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景颜色
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Horizontal filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterPill(title: "All", isSelected: timeFilter == .all) {
                                timeFilter = .all
                                viewModel.applyTimeFilter(timeFilter)
                            }
                            
                            FilterPill(title: "Last Week", isSelected: timeFilter == .lastWeek) {
                                timeFilter = .lastWeek
                                viewModel.applyTimeFilter(timeFilter)
                            }
                            
                            FilterPill(title: "Last Month", isSelected: timeFilter == .lastMonth) {
                                timeFilter = .lastMonth
                                viewModel.applyTimeFilter(timeFilter)
                            }
                            
                            FilterPill(title: "Last 6 Months", isSelected: timeFilter == .lastSixMonths) {
                                timeFilter = .lastSixMonths
                                viewModel.applyTimeFilter(timeFilter)
                            }
                            
                            FilterPill(title: "Last Year", isSelected: timeFilter == .lastYear) {
                                timeFilter = .lastYear
                                viewModel.applyTimeFilter(timeFilter)
                            }
                            
                            FilterPill(title: "Starred", isSelected: showStarredOnly, 
                                       icon: "star.fill", 
                                       color: showStarredOnly ? .yellow : .primary) {
                                showStarredOnly.toggle()
                                viewModel.filterStarredOnly(showStarredOnly)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(
                        Color(.systemBackground)
                            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                    )
                    .padding(.bottom, 8)
                    
                    // Main content
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Spacer()
                    } else if viewModel.timelineItems.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 22) {
                                // 根据当前排序顺序选择正确的日期排序方向
                                let dateSortOrder: (Date, Date) -> Bool = viewModel.sortOrder == .newestFirst ? (>) : (<)
                                
                                ForEach(viewModel.groupedByDate.keys.sorted(by: dateSortOrder), id: \.self) { date in
                                    if let items = viewModel.groupedByDate[date] {
                                        // 根据当前排序顺序对组内项目进行排序
                                        let sortedItems: [TimelineItem] = viewModel.sortOrder == .newestFirst ?
                                            items.sorted(by: { $0.date > $1.date }) :
                                            items.sorted(by: { $0.date < $1.date })
                                        
                                        dateSection(date: date, items: sortedItems)
                                    }
                                }
                            }
                            .padding(.top, 15)
                            .padding(.bottom, 30)
                        }
                        .refreshable {
                            await viewModel.loadTimelineData()
                        }
                    }
                }
                
            }
            .navigationTitle("Memories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            viewModel.sortOrder = .newestFirst
                            viewModel.applySorting()
                        }) {
                            Label("Newest First", systemImage: "arrow.down")
                                .foregroundColor(viewModel.sortOrder == .newestFirst ? .blue : .primary)
                        }
                        
                        Button(action: {
                            viewModel.sortOrder = .oldestFirst
                            viewModel.applySorting()
                        }) {
                            Label("Oldest First", systemImage: "arrow.up")
                                .foregroundColor(viewModel.sortOrder == .oldestFirst ? .blue : .primary)
                        }
                        
                        Divider()
                        
                        Button(action: {
                            viewModel.filter = .all
                        }) {
                            Label("All Items", systemImage: "photo.on.rectangle")
                                .foregroundColor(viewModel.filter == .all ? .blue : .primary)
                        }
                        
                        Button(action: {
                            viewModel.filter = .memoriesOnly
                        }) {
                            Label("Memories Only", systemImage: "text.book.closed")
                                .foregroundColor(viewModel.filter == .memoriesOnly ? .blue : .primary)
                        }
                        
                        Button(action: {
                            viewModel.filter = .photosOnly
                        }) {
                            Label("Photos Only", systemImage: "photo")
                                .foregroundColor(viewModel.filter == .photosOnly ? .blue : .primary)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(item: $selectedItem, onDismiss: { selectedItem = nil }) { item in
                Group {
                    // 无论是否有记忆，都优先显示地点详情
                    if let place = item.place {
                        PlaceDetailView(place: place)
                    } else if let memory = item.memory {
                        // 这个分支一般不会执行，除非是独立的记忆项
                        MemoryDetailView(memory: memory)
                    }
                }
            }
            .sheet(isPresented: $showAddMemory) {
                AddMemoryView(place: placeForNewMemory) { success in
                    showAddMemory = false
                    placeForNewMemory = nil
                    if success {
                        Task {
                            await viewModel.loadTimelineData()
                        }
                    }
                }
            }
            .task {
                await viewModel.loadTimelineData()
            }
            .onAppear {
                setupNotifications()
            }
            .onDisappear {
                removeNotifications()
            }
        }
    }
    
    // Setup notification observers
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AddMemoryToPlace"),
            object: nil,
            queue: .main
        ) { notification in
            if let place = notification.object as? Place {
                self.placeForNewMemory = place
                self.showAddMemory = true
            }
        }
    }
    
    // Remove notification observers
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("AddMemoryToPlace"),
            object: nil
        )
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 70))
                .foregroundColor(.secondary.opacity(0.7))
            
            Text("No Memories Yet")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Your photos and memories will appear here as you explore places.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                // Navigate to map tab
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController as? UITabBarController {
                    rootViewController.selectedIndex = 0 // 假设Map是第一个tab
                }
            }) {
                Text("Explore Map")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
    
    // 每一个日期分区
    private func dateSection(date: Date, items: [TimelineItem]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 日期标题
            HStack {
                Text(formatSectionDate(date))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                
                Spacer()
                
                Text("\(items.count) items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.2))
                    .offset(y: 15),
                alignment: .bottom
            )
            
            // 卡片网格
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 160), spacing: 16)], spacing: 16) {
                ForEach(items) { item in
                    timelineItemCard(item: item)
                        .frame(height: 220) // 固定高度
                        .frame(maxWidth: .infinity) // 最大宽度
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }
    
    // 时间线项目卡片
    private func timelineItemCard(item: TimelineItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // 图片容器 - 添加固定padding确保与边缘有距离
                VStack {
                    if let image = item.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 140)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .padding(4) // 添加内边距
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // 类型标签和操作按钮
                HStack(spacing: 4) {
                    // 显示记忆操作菜单
                    if item.hasMemory, let memory = item.memory {
                        Menu {
                            Button(action: {
                                viewModel.toggleStarred(item)
                            }) {
                                Label(
                                    memory.isStarred ? "Unstar" : "Star",
                                    systemImage: memory.isStarred ? "star.slash" : "star"
                                )
                            }
                            
                            Button(action: {
                                selectedItem = item
                            }) {
                                Label("View Details", systemImage: "eye")
                            }
                            
                            Button(action: {
                                // 显示编辑视图 - 通过将选择的项目设置为该项目间接触发
                                selectedItem = item
                                // 需要添加编辑标志，可以在PlaceDetailView中实现
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive, action: {
                                viewModel.deleteItem(item)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                            
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.footnote)
                                .padding(6)
                                .background(Color.gray.opacity(0.8))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 4)
                        
                        // 星标状态
                        if memory.isStarred {
                            Image(systemName: "star.fill")
                                .font(.footnote)
                                .padding(6)
                                .background(Color.yellow.opacity(0.9))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .padding(.trailing, 4)
                        }
                    }
                    
                    // 图标 - 照片或记忆
                    Image(systemName: item.hasMemory ? "text.book.closed.fill" : "photo.fill")
                        .font(.footnote)
                        .padding(6)
                        .background(item.hasMemory ? Color.blue.opacity(0.9) : Color.green.opacity(0.9))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding(12)
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            
            // 标题和时间放在一个容器内，不会超出边缘
            VStack(alignment: .leading, spacing: 4) {
                // 标题 - 对于有记忆的照片，显示记忆标题和地点名称
                if item.hasMemory, let memory = item.memory {
                    Text(memory.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // 地点名称
                    if let place = item.place {
                        Text(place.name)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    // 普通照片，显示地点名称
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // 时间
                    Text(formatTime(item.date))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .onTapGesture {
            selectedItem = item
        }
    }
    
    // 格式化日期区域标题
    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    // 格式化时间
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// Filter pill component
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.footnote)
                        .foregroundColor(isSelected ? .white : color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color.gray.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isSelected ? color.opacity(0.3) : Color.clear, radius: 3, x: 0, y: 1)
        }
    }
}

// 添加记忆的视图
struct AddMemoryView: View {
    let place: Place?
    let onComplete: (Bool) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var isStarred = false
    @StateObject private var viewModel = MemoriesViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("New Memory")) {
                    TextField("Title", text: $title)
                    
                    TextEditor(text: $description)
                        .frame(minHeight: 150)
                        .overlay(
                            Group {
                                if description.isEmpty {
                                    Text("Describe your experience...")
                                        .foregroundColor(.gray.opacity(0.7))
                                        .padding(.leading, 5)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                        )
                        
                    Toggle(isOn: $isStarred) {
                        Label("Star this memory", systemImage: "star")
                    }
                }
                
                if let place = place {
                    Section(header: Text("Location")) {
                        VStack(alignment: .leading) {
                            Text(place.name)
                                .font(.headline)
                            
                            if let address = place.address {
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onComplete(false)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMemory()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveMemory() {
        if let place = place {
            // 创建记忆
            let memory = MemoryStore.shared.createMemory(
                placeId: place.id, 
                title: title, 
                text: description, 
                isStarred: isStarred
            )
            
            // 确保发送通知以更新其他视图
            if memory != nil {
                NotificationCenter.default.post(
                    name: NSNotification.Name("MemoriesUpdated"),
                    object: nil
                )
            }
            
            // 使用ViewModel的方法刷新MemoriesView中的数据
            Task {
                await viewModel.loadTimelineData()
            }
            
            onComplete(true)
        } else {
            onComplete(false)
        }
    }
}

#Preview {
    MemoriesListView()
}
