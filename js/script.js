


document.addEventListener("DOMContentLoaded", () => {

    // Seleccionar elementos
    const menuButton = document.getElementById("menu-button");
    const nav = document.querySelector(".nav");
    const navLinks = document.querySelectorAll(".nav-link");

    // Comprobar que existen los elementos
    if (!menuButton || !nav) {
        return;
    }

    // Función para abrir el menú
    function openMenu() {
        nav.classList.add("is-open");
        menuButton.setAttribute("aria-expanded", "true");
        menuButton.setAttribute("aria-label", "Cerrar menú");
        menuButton.textContent = "✕";
    }

    // Función para cerrar el menú
    function closeMenu() {
        nav.classList.remove("is-open");
        menuButton.setAttribute("aria-expanded", "false");
        menuButton.setAttribute("aria-label", "Abrir menú");
        menuButton.textContent = "☰";
    }

    // Alternar menú
    menuButton.addEventListener("click", () => {

        const isOpen = nav.classList.contains("is-open");

        if (isOpen) {
            closeMenu();
        } else {
            openMenu();
        }

    });

    // Cerrar al seleccionar un enlace
    navLinks.forEach(link => {

        link.addEventListener("click", () => {
            closeMenu();
        });

    });

    // Cerrar al pulsar fuera del menú
    document.addEventListener("click", (event) => {

        const clickedInsideMenu = nav.contains(event.target);
        const clickedButton = menuButton.contains(event.target);

        if (!clickedInsideMenu && !clickedButton) {
            closeMenu();
        }

    });

    // Cerrar al cambiar a escritorio
    window.addEventListener("resize", () => {

        if (window.innerWidth > 700) {
            closeMenu();
        }

    });

});
