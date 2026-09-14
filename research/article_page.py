"""Structural checks shared by article packaging and local staging."""
from html.parser import HTMLParser


class Page(HTMLParser):
    VOID_TAGS = {
        'meta', 'link', 'img', 'br', 'hr', 'input', 'source', 'wbr',
        'area', 'base', 'col', 'embed', 'param', 'track',
    }

    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []
        self.images = []
        self.stack = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        identifier = attrs.get('id')
        if identifier is not None:
            assert identifier not in self.ids, f'Duplicate id {identifier}'
            self.ids.add(identifier)
        for key in ('href', 'src'):
            if key in attrs:
                self.links.append(attrs[key])
        if tag == 'img':
            assert attrs.get('alt'), 'Image missing alternative text'
            self.images.append(attrs['src'])
        if tag not in self.VOID_TAGS:
            self.stack.append(tag)

    def handle_endtag(self, tag):
        assert self.stack and self.stack[-1] == tag, f'Mismatched HTML tag {tag}'
        self.stack.pop()

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
