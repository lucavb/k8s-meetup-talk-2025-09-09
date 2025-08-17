# Kubernetes + Karpenter + AI Presentation

This is a [Slidev](https://sli.dev) presentation about Kubernetes, Karpenter, and AI workload scaling.

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Start the dev server
npm run dev

# Open http://localhost:3030 in your browser
```

## 📊 Presentation Features

### **Navigation**
- **Space / Arrow Right**: Next slide or animation
- **Arrow Left**: Previous slide or animation  
- **Arrow Up/Down**: Navigate between slides (skip animations)
- **o**: Overview mode (see all slides)
- **p**: Presenter mode (with speaker notes)
- **f**: Fullscreen mode
- **ESC**: Exit current mode

### **Presenter Mode**
- Press `p` to enter presenter mode
- Shows current slide, next slide, timer, and speaker notes
- Perfect for giving live presentations

### **Live Editing**
- Edit `slides.md` and see changes instantly
- Hot reload preserves your current slide position
- Great for last-minute adjustments before presenting

## 🎨 Customization

### **Theme & Styling**
The presentation uses the `seriph` theme with custom styling:
- Background images from Unsplash
- Custom color scheme for tech presentations  
- Optimized fonts and spacing for readability

### **Content Structure**
```markdown
---
# Slide frontmatter (YAML)
layout: center
class: text-center  
transition: slide-left
---

# Slide Content
Your markdown content here with Slidev features:

<v-click>Animated content</v-click>
<v-clicks>Multiple items</v-clicks>
```

### **Interactive Elements**
- **Click animations**: `<v-click>` for progressive disclosure
- **Code highlighting**: Syntax highlighting with line emphasis
- **Diagrams**: Mermaid diagrams embedded directly
- **Magic Move**: Smooth transitions between code blocks

## 📄 Export Options

### **PDF Export**
```bash
npm run export
# Creates slides-export.pdf
```

### **Static Site**
```bash  
npm run build
# Creates dist/ folder for hosting
```

### **PNG Images**
```bash
npm run export -- --format png
# Exports each slide as PNG
```

## 🎯 Presentation Tips

### **Before Presenting**
1. Test slides in fullscreen mode (`f`)
2. Practice with presenter mode (`p`)
3. Verify all animations and transitions work
4. Have backup slides ready for deep-dive questions

### **During Presentation**
- Use presenter mode for speaker notes and timing
- Remember: Space bar advances animations smoothly
- Use overview mode (`o`) to jump to specific sections
- Keep the AWS demo terminal open in another window

### **Technical Setup**
- **Display**: 1920x1080 recommended resolution
- **Browser**: Chrome/Firefox/Safari all work well
- **Backup**: Export PDF version as fallback
- **Internet**: Required for external images and fonts

## 🔧 Development

### **Adding Slides**
Add new slides by separating content with `---`:

```markdown
---
# Previous slide content
---

# New slide
Content for new slide

---
# Next slide
```

### **Custom Components**
Add Vue components in `components/` directory:

```vue
<!-- components/CustomDemo.vue -->
<template>
  <div class="demo-container">
    <!-- Your custom component -->
  </div>
</template>
```

### **Styling**
Add custom CSS with `<style>` blocks in slides:

```markdown
<style>
.custom-class {
  color: #4ade80;
}
</style>
```

## 📚 Slidev Resources

- **Documentation**: [sli.dev](https://sli.dev)
- **Themes**: [sli.dev/resources/theme-gallery](https://sli.dev/resources/theme-gallery)
- **Examples**: [sli.dev/resources/showcases](https://sli.dev/resources/showcases)
- **Community**: [Discord](https://chat.sli.dev)

## 🐛 Troubleshooting

### **Common Issues**
- **Slides not updating**: Check for YAML syntax errors in frontmatter
- **Images not loading**: Verify internet connection for external images
- **Presenter mode issues**: Try refreshing the browser
- **Export fails**: Ensure all dependencies are installed

### **Performance Tips**  
- Keep image sizes reasonable (< 2MB each)
- Minimize complex animations on slower machines
- Test on the actual presentation hardware beforehand

---

**Happy Presenting! 🎤**