class StringUtils {
  static String removeDiacritics(String str) {
    var withDia = 'ÁÉÍÓÚÁÉÍÓÚáéíóúáéíóúÄËÏÖÜäëïöü';
    var withoutDia = 'AEIOUAEIOUaeiouaeiouAEIOUaeiou';

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }

    return str;
  }
}
