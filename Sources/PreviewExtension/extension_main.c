// Standard entry point for an NSExtension-based app extension.
// PluginKit/Foundation provides NSExtensionMain; we just hand off to it.
extern int NSExtensionMain(int argc, const char *argv[]);

int main(int argc, const char *argv[]) {
    return NSExtensionMain(argc, argv);
}
