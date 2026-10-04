import re

file_path = "lib/repositories/app_repository.dart"

with open(file_path, "r") as f:
    content = f.read()

# We need to replace the _users and _posts arrays in _seedInitialDemoData

users_str = """_users = [
      User(
        id: 'u_viewer',
        name: 'Aanya Sharma (Viewer)',
        username: 'aanya_shopper',
        avatarUrl: 'assets/images/viewer_aanya.png',
        role: UserRole.viewer,
        bio: 'Lifestyle enthusiast & avid shopper!',
      ),
      User(id: 'u_creator1', name: 'Priya Fashionista', username: 'priya_style', avatarUrl: 'assets/images/creator_priya.png', role: UserRole.creator, isVerifiedCreator: true, bio: 'Fashion creator based in Mumbai ✨', followerCount: 1420),
      User(id: 'u_creator2', name: 'Rahul Style', username: 'rahul_fashion', avatarUrl: 'assets/images/creator_rohan.png', role: UserRole.creator, isVerifiedCreator: false, bio: 'Men\\'s fashion & streetwear.', followerCount: 890),
      User(id: 'u_creator3', name: 'Simran Glow', username: 'simran_beauty', avatarUrl: 'assets/images/creator_priya.png', role: UserRole.creator, isVerifiedCreator: true, bio: 'Beauty & Skincare routines 💄', followerCount: 3400),
      User(id: 'u_creator4', name: 'Kavya Looks', username: 'kavya_makeup', avatarUrl: 'assets/images/creator_priya.png', role: UserRole.creator, isVerifiedCreator: false, bio: 'Makeup tutorials and product reviews.', followerCount: 1200),
      User(id: 'u_creator5', name: 'Rohan Traveler', username: 'rohan_explores', avatarUrl: 'assets/images/creator_rohan.png', role: UserRole.creator, isVerifiedCreator: true, bio: 'Exploring hidden spots & tech gear 🎒', followerCount: 8900),
      User(id: 'u_creator6', name: 'Aryan Nomad', username: 'aryan_travels', avatarUrl: 'assets/images/creator_rohan.png', role: UserRole.creator, isVerifiedCreator: false, bio: 'Backpacking across the globe 🌍', followerCount: 2300),
      User(id: 'u_creator7', name: 'Megha Bites', username: 'megha_foodie', avatarUrl: 'assets/images/creator_priya.png', role: UserRole.creator, isVerifiedCreator: true, bio: 'Street food lover & recipe creator 🥘', followerCount: 4500),
      User(id: 'u_creator8', name: 'Chef Karan', username: 'karan_cooks', avatarUrl: 'assets/images/creator_rohan.png', role: UserRole.creator, isVerifiedCreator: false, bio: 'Home cooking made easy 👨‍🍳', followerCount: 1500),
      User(id: 'u_creator9', name: 'Diya Crafts', username: 'diya_diy', avatarUrl: 'assets/images/creator_priya.png', role: UserRole.creator, isVerifiedCreator: true, bio: 'DIY crafts and home decor 🧶', followerCount: 2800),
      User(id: 'u_creator10', name: 'Lifestyle With Sam', username: 'sam_lifestyle', avatarUrl: 'assets/images/creator_rohan.png', role: UserRole.creator, isVerifiedCreator: true, bio: 'Fashion, food, and everything in between ✨', followerCount: 5600),
      User(id: 'u_admin', name: 'Trell Admin', username: 'admin_portal', avatarUrl: 'assets/images/creator_rohan.png', role: UserRole.admin, bio: 'Platform Moderator & Administrator'),
    ];"""

posts_list = []
categories = ["Fashion", "Beauty", "Travel", "Food", "DIY"]
users_map = {
    "Fashion": ["u_creator1", "u_creator2", "u_creator10"],
    "Beauty": ["u_creator3", "u_creator4", "u_creator10"],
    "Travel": ["u_creator5", "u_creator6", "u_creator10"],
    "Food": ["u_creator7", "u_creator8", "u_creator10"],
    "DIY": ["u_creator9", "u_creator10", "u_creator10"]
}

product_map = {
    "Fashion": "p_2",
    "Beauty": "p_1",
    "Travel": "p_3",
    "Food": "p_4",
    "DIY": "p_5"
}

import random

for cat in categories:
    for i in range(1, 6):
        user_id = users_map[cat][i % 3]
        post_id = f"post_{cat.lower()}_{i}"
        vid_path = f"assets/videos/categories/{cat.lower()}/{cat.lower()}_{i:02d}.mp4"
        img_path = f"assets/images/categories/{cat.lower()}/{cat.capitalize()}_{i:02d}.png"
        prod_id = product_map[cat]
        post_str = f"""      Post(
        id: '{post_id}',
        creatorId: '{user_id}',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: '{vid_path}',
        caption: 'Awesome {cat.lower()} content #{i}! Check this out. #{cat}',
        category: '{cat}',
        taggedProductIds: ['{prod_id}'],
        viewsCount: {random.randint(100, 2000)},
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: {random.randint(5, 50)},
        productClicksCount: {random.randint(10, 100)},
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: {i})),
      ),"""
        posts_list.append(post_str)

posts_str = "_posts = [\n" + "\n".join(posts_list) + "\n    ];"

# We replace the chunks
content = re.sub(r"_users\s*=\s*\[.*?\];", users_str, content, flags=re.DOTALL)
content = re.sub(r"_posts\s*=\s*\[.*?\];", posts_str, content, flags=re.DOTALL)

with open(file_path, "w") as f:
    f.write(content)

print("Updated app_repository.dart successfully")
