class Passkeys {
  static async login (event) {
    event.preventDefault();
    const button = document.getElementById("passkey-login-button");
    const form = document.getElementById("passkey-login-form");
    const errorEl = form.querySelector(".passkey-error");
    errorEl.hidden = true;

    try {
      button.disabled = true;
      const options = PublicKeyCredential.parseRequestOptionsFromJSON(JSON.parse(button.dataset.options));
      const credential = await navigator.credentials.get({ publicKey: options });
      form.querySelector("[name='passkey[credential]']").value = JSON.stringify(credential.toJSON());
      form.submit();
    } catch (error) {
      errorEl.textContent = "Couldn't verify passkey: " + error.message;
      errorEl.hidden = false;
      button.disabled = false;
    }
  }

  static async register (event) {
    event.preventDefault();
    const button = document.getElementById("passkey-register-button");
    const form = document.getElementById("passkey-register-form");
    const errorEl = form.querySelector(".passkey-error");
    errorEl.hidden = true;

    try {
      button.disabled = true;
      const options = PublicKeyCredential.parseCreationOptionsFromJSON(JSON.parse(button.dataset.options));
      const credential = await navigator.credentials.create({ publicKey: options });
      form.querySelector("[name='passkey[credential]']").value = JSON.stringify(credential.toJSON());
      form.submit();
    } catch (error) {
      errorEl.textContent = "Couldn't register passkey: " + error.message;
      errorEl.hidden = false;
      button.disabled = false;
    }
  }

  static init () {
    const loginButton = document.getElementById("passkey-login-button");
    if (loginButton) loginButton.addEventListener("click", Passkeys.login);

    const registerButton = document.getElementById("passkey-register-button");
    if (registerButton) registerButton.addEventListener("click", Passkeys.register);
  }
}

$(function () {
  if (window.PublicKeyCredential) Passkeys.init();
});

export default Passkeys;
