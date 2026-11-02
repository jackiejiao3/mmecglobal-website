/* Gallery layout must not wait for window.load or eagerly fetch offscreen images. */
(function ($) {
    'use strict';

    $(function () {
        var $grid = $('[data-gallery-grid]');
        if (!$grid.length || !$.fn.isotope) return;

        $grid.isotope({
            itemSelector: '.masonry-item',
            transitionDuration: '0.3s',
            originLeft: true
        });

        var layoutPending = false;
        function layout() {
            if (layoutPending) return;
            layoutPending = true;
            window.requestAnimationFrame(function () {
                layoutPending = false;
                $grid.isotope('layout');
            });
        }

        // Native events observe actual loads; imagesLoaded creates eager proxy Images.
        $grid.find('img').each(function () {
            this.addEventListener('load', layout);
            this.addEventListener('error', layout);
        });

        $('.masonry-filter').on('click.gallery', 'a[data-filter]', function (event) {
            event.preventDefault();
            var $link = $(this);
            $link.closest('ul').find('li').removeClass('active');
            $link.parent().addClass('active');
            $grid.isotope({ filter: $link.attr('data-filter') });
        });

        // Font metrics can change caption heights after the initial layout.
        if (document.fonts && document.fonts.ready) document.fonts.ready.then(layout);
    });
}(jQuery));
