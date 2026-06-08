enum EnvironmentType { dev, prod }

class Environment {
  static late EnvironmentType _currentEnv;

  static EnvironmentType get currentEnv => _currentEnv;

  static void init(EnvironmentType env) {
    _currentEnv = env;
  }

  static bool get isDev => _currentEnv == EnvironmentType.dev;
  static bool get isProd => _currentEnv == EnvironmentType.prod;
}
